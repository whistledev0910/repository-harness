#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGESET_DIR="${HARNESS_CHANGESET_DIR:-$ROOT_DIR/.harness/changesets}"

select_harness_cli() {
  local root_dir="$1"
  if [[ -n "${HARNESS_CLI:-}" ]]; then
    printf '%s\n' "$HARNESS_CLI"
    return
  fi
  if [[ "${HARNESS_VALIDATOR_SKIP_BUILD:-0}" != "1" ]]; then
    cargo build --quiet --manifest-path "$root_dir/Cargo.toml" -p harness-cli
  fi
  printf '%s\n' "$root_dir/target/debug/harness-cli"
}

proof_is_valid() {
  local database="$1"
  local story_id="$2"
  [[ "$(sqlite3 "$database" "
    SELECT CASE WHEN last_verified_result='pass'
      AND length(last_verified_at)=19
      AND last_verified_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]'
      AND datetime(last_verified_at)=last_verified_at
    THEN 1 ELSE 0 END
    FROM story WHERE id='$story_id';")" == "1" ]]
}

if [[ "${HARNESS_VALIDATOR_LIBRARY_ONLY:-0}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HARNESS_CLI="$(select_harness_cli "$ROOT_DIR")"
if [[ ! -x "$HARNESS_CLI" ]]; then
  echo "Harness CLI not found; build it with: cargo build -p harness-cli" >&2
  exit 1
fi

echo "rebuild validator executable: $HARNESS_CLI"
echo "rebuild validator source: $(git -C "$ROOT_DIR" rev-parse --verify HEAD)"
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=no)" ]]; then
  echo "rebuild validator source state: dirty workspace (current files were rebuilt)"
else
  echo "rebuild validator source state: clean workspace"
fi

HARNESS_DB_PATH="$TMP_DIR/harness.db" \
  "$HARNESS_CLI" db rebuild --from "$CHANGESET_DIR" >/dev/null

expected_ids=(
  US-028 US-029 US-030 US-031 US-032 US-033 US-034 US-035 US-036 US-037
  US-038 US-039 US-040 US-041 US-042 US-043 US-044 US-045 US-046 US-047
  US-048 US-049 US-050 US-051 US-052 US-053 US-054 US-055 US-056 US-057
  US-058 US-059 US-060 US-061 US-062 US-063 US-SYM-001
  US-064 US-065 US-066 US-067 US-068 US-069 US-070 US-071 US-072
  US-073 US-074 US-075 US-076 US-077 US-078 US-079 US-080 US-081 US-082
  US-083 US-084 US-085
)

for id in "${expected_ids[@]}"; do
  count="$(sqlite3 "$TMP_DIR/harness.db" "SELECT COUNT(*) FROM story WHERE id='$id';")"
  if [[ "$count" != "1" ]]; then
    echo "missing rebuilt story row: $id" >&2
    exit 1
  fi
done

retired_count="$(
  sqlite3 "$TMP_DIR/harness.db" \
    "SELECT COUNT(*) FROM story WHERE id IN ('US-061', 'US-063') AND status='retired';"
)"
if [[ "$retired_count" != "2" ]]; then
  echo "expected US-061 and US-063 to rebuild as retired" >&2
  exit 1
fi

expected_e09_edges=(
  'US-073|US-074'
  'US-074|US-075'
  'US-074|US-076'
  'US-075|US-077'
  'US-076|US-077'
  'US-077|US-078'
  'US-078|US-079'
  'US-075|US-080'
  'US-078|US-080'
  'US-080|US-082'
  'US-082|US-083'
  'US-083|US-084'
  'US-084|US-085'
)

for edge in "${expected_e09_edges[@]}"; do
  blocker="${edge%%|*}"
  blocked="${edge##*|}"
  count="$(sqlite3 "$TMP_DIR/harness.db" "SELECT COUNT(*) FROM story_dependency WHERE story_id='$blocker' AND blocks_story_id='$blocked';")"
  if [[ "$count" != "1" ]]; then
    echo "missing rebuilt E09 dependency edge: $blocker -> $blocked" >&2
    exit 1
  fi
done

for story_id in US-073 US-074 US-075 US-076 US-077 US-078 US-079 US-080 US-081 US-082 US-083 US-084 US-085; do
  if ! proof_is_valid "$TMP_DIR/harness.db" "$story_id"; then
    actual="$(sqlite3 "$TMP_DIR/harness.db" "SELECT COALESCE(last_verified_result,'') || '|' || COALESCE(last_verified_at,'') FROM story WHERE id='$story_id';")"
    echo "rebuilt proof invalid for $story_id: expected pass with canonical timestamp, got $actual" >&2
    exit 1
  fi
done

unexpected_unverified="$(
  sqlite3 "$TMP_DIR/harness.db" \
    "SELECT COUNT(*) FROM story WHERE id BETWEEN 'US-073' AND 'US-081' AND last_verified_result IS NULL;"
)"
if [[ "$unexpected_unverified" != "0" ]]; then
  echo "rebuilt E09 stories US-073..US-081 must all retain verification proof" >&2
  exit 1
fi

audit_output="$(HARNESS_DB_PATH="$TMP_DIR/harness.db" "$HARNESS_CLI" audit)"
if ! grep -q 'Entropy score: 0/100' <<<"$audit_output"; then
  echo "rebuilt Harness audit must have zero entropy" >&2
  printf '%s\n' "$audit_output" >&2
  exit 1
fi

echo "changeset rebuild restored ${#expected_ids[@]} Symphony story rows"
