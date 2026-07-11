#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT_DIR/scripts/validate-changeset-rebuild.sh"
CLI="$ROOT_DIR/target/debug/harness-cli"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cargo build --quiet --manifest-path "$ROOT_DIR/Cargo.toml" -p harness-cli
HARNESS_VALIDATOR_LIBRARY_ONLY=1 source "$VALIDATOR"
unset HARNESS_VALIDATOR_LIBRARY_ONLY

default_output="$(env -u HARNESS_CLI "$VALIDATOR")"
grep -Fq "rebuild validator executable: $CLI" <<<"$default_output"

override_output="$(HARNESS_CLI="$CLI" "$VALIDATOR")"
grep -Fq "rebuild validator executable: $CLI" <<<"$override_output"

if HARNESS_CLI="$TMP_DIR/missing-cli" "$VALIDATOR" >"$TMP_DIR/missing.out" 2>&1; then
  echo "validator unexpectedly accepted a missing explicit CLI" >&2
  exit 1
fi
grep -Fq "Harness CLI not found" "$TMP_DIR/missing.out"

selection_root="$TMP_DIR/selection-root"
mkdir -p "$selection_root/target/debug" "$selection_root/scripts/bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$selection_root/target/debug/harness-cli"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$selection_root/scripts/bin/harness-cli"
chmod +x "$selection_root/target/debug/harness-cli" "$selection_root/scripts/bin/harness-cli"
touch -t 209912312359 "$selection_root/scripts/bin/harness-cli"
selected="$(HARNESS_CLI= HARNESS_VALIDATOR_SKIP_BUILD=1 select_harness_cli "$selection_root")"
[[ "$selected" == "$selection_root/target/debug/harness-cli" ]]

copy_changesets() {
  local destination="$1"
  mkdir -p "$destination"
  cp "$ROOT_DIR"/.harness/changesets/*.jsonl "$destination/"
}

later_dir="$TMP_DIR/later"
copy_changesets "$later_dir"
printf '%s\n' \
  '{"op":"changeset.header","version":1,"run_id":"run_9999999997_later_verify","base_schema_version":12}' \
  '{"op":"story.verify","version":2,"id":"US-073","payload":{"result":"pass","verified_at":"2099-01-02 03:04:05"}}' \
  >"$later_dir/run_9999999997_later_verify.changeset.jsonl"
HARNESS_CLI="$CLI" HARNESS_CHANGESET_DIR="$later_dir" "$VALIDATOR" >/dev/null
HARNESS_DB_PATH="$TMP_DIR/later.db" "$CLI" db rebuild --from "$later_dir" >/dev/null
later_value="$(sqlite3 "$TMP_DIR/later.db" "SELECT last_verified_result || '|' || last_verified_at FROM story WHERE id='US-073';")"
[[ "$later_value" == "pass|2099-01-02 03:04:05" ]]

garbage_dir="$TMP_DIR/garbage"
copy_changesets "$garbage_dir"
printf '%s\n' \
  '{"op":"changeset.header","version":1,"run_id":"run_9999999998_garbage_verify","base_schema_version":12}' \
  '{"op":"story.verify","version":2,"id":"US-073","payload":{"result":"pass","verified_at":"garbage"}}' \
  >"$garbage_dir/run_9999999998_garbage_verify.changeset.jsonl"
if HARNESS_DB_PATH="$TMP_DIR/garbage.db" "$CLI" db rebuild --from "$garbage_dir" >"$TMP_DIR/garbage.out" 2>&1; then
  echo "operation replay unexpectedly accepted a garbage proof timestamp" >&2
  exit 1
fi
grep -Fq "verified_at must use YYYY-MM-DD HH:MM:SS" "$TMP_DIR/garbage.out"

missing_dir="$TMP_DIR/missing-timestamp"
copy_changesets "$missing_dir"
printf '%s\n' \
  '{"op":"changeset.header","version":1,"run_id":"run_9999999999_missing_verify","base_schema_version":12}' \
  '{"op":"story.verify","version":2,"id":"US-073","payload":{"result":"pass"}}' \
  >"$missing_dir/run_9999999999_missing_verify.changeset.jsonl"
if HARNESS_DB_PATH="$TMP_DIR/missing.db" "$CLI" db rebuild --from "$missing_dir" >"$TMP_DIR/missing-timestamp.out" 2>&1; then
  echo "operation replay unexpectedly accepted missing proof time" >&2
  exit 1
fi
grep -Fq "story.verify version 2 requires verified_at" "$TMP_DIR/missing-timestamp.out"

proof_db="$TMP_DIR/proof-query.db"
HARNESS_DB_PATH="$proof_db" "$CLI" db rebuild --from "$ROOT_DIR/.harness/changesets" >/dev/null
sqlite3 "$proof_db" "UPDATE story SET last_verified_result='pass', last_verified_at='garbage' WHERE id='US-073';"
if proof_is_valid "$proof_db" US-073; then
  echo "proof SQL unexpectedly accepted garbage timestamp" >&2
  exit 1
fi
sqlite3 "$proof_db" "UPDATE story SET last_verified_at=NULL WHERE id='US-073';"
if proof_is_valid "$proof_db" US-073; then
  echo "proof SQL unexpectedly accepted missing timestamp" >&2
  exit 1
fi
sqlite3 "$proof_db" "UPDATE story SET last_verified_at='2099-01-02 03:04:05' WHERE id='US-073';"
proof_is_valid "$proof_db" US-073

echo "rebuild validator contract tests passed"
