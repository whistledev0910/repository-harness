#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIR="${US100_EVIDENCE_DIR:-$ROOT_DIR/docs/stories/epics/E11-symphony-repository-separation/US-100-cutover-and-post-separation-audit/evidence}"
MODE="${1:---final}"

case "$MODE" in
  --develop-candidate|--readiness|--final) ;;
  *) echo "usage: $0 [--develop-candidate|--readiness|--final]" >&2; exit 2 ;;
esac

fail() { echo "US-100 verification failed: $*" >&2; exit 1; }
need() { test -e "$1" || fail "required evidence is missing: $1"; }

for command in git jq shasum sqlite3; do
  command -v "$command" >/dev/null || fail "required command is missing: $command"
done

RELEASE="$EVIDENCE_DIR/symphony-release.json"
PREMERGE="$EVIDENCE_DIR/premerge-released-cross-repo-smokes.json"
CUTOVER="$EVIDENCE_DIR/cutover-readiness.json"
ROLLBACK="$EVIDENCE_DIR/rollback-rehearsal.json"
ROLLBACK_SUM="$ROLLBACK.sha256"
CANONICAL_TARGET="$EVIDENCE_DIR/canonical-target-ownership.json"
CANONICAL_TARGET_SUM="$CANONICAL_TARGET.sha256"
RUNTIME_DISPOSITION="$EVIDENCE_DIR/runtime-disposition.json"
RUNTIME_DISPOSITION_SUM="$RUNTIME_DISPOSITION.sha256"

for file in "$RELEASE" "$PREMERGE" "$ROLLBACK" "$ROLLBACK_SUM" "$CANONICAL_TARGET" "$CANONICAL_TARGET_SUM" "$RUNTIME_DISPOSITION" "$RUNTIME_DISPOSITION_SUM"; do need "$file"; done

# The sidecar proves that the reviewed rollback record is the record being used.
(cd "$EVIDENCE_DIR" && shasum -a 256 -c "$(basename "$ROLLBACK_SUM")") >/dev/null \
  || fail "rollback rehearsal checksum does not match"
jq -e '
  .schema == "e11-us100-rollback-rehearsal-v1" and
  .mode == "scratch-copy-read-only" and
  .source_epoch.integrity_check == "ok" and .source_epoch.foreign_key_violations == 0 and
  .target_pre_reconcile_epoch.integrity_check == "ok" and .target_pre_reconcile_epoch.foreign_key_violations == 0 and
  .target_post_reconcile_epoch.integrity_check == "ok" and .target_post_reconcile_epoch.foreign_key_violations == 0 and
  (.source_bundle.sha256 | test("^[0-9a-f]{64}$")) and
  .source_bundle.verify == "complete history" and
  .target_raw_import_tag.tag == "symphony-raw-import-20260712" and
  (.target_raw_import_tag.peeled_commit | test("^[0-9a-f]{40}$"))
' "$ROLLBACK" >/dev/null || fail "rollback rehearsal record is incomplete"

# This checksummed record was produced from a clean clone of the canonical
# remote. It prevents a local target checkout from standing in for published
# repository ownership.
(cd "$EVIDENCE_DIR" && shasum -a 256 -c "$(basename "$CANONICAL_TARGET_SUM")") >/dev/null \
  || fail "canonical target ownership checksum does not match"
jq -e '
  .schema == "e11-us100-canonical-target-ownership-v1" and
  .repository == "hoangnb24/symphony" and
  .commit == "2f0b257a0b145287c4b3b9e254fea5eca454c228" and
  .branch == "main" and .tag == "symphony-v0.1.1" and
  .clean == true and .forbidden_tracked_paths == 0 and
  .forbidden_hidden_directories == 0 and .active_durable_databases == 0 and
  .verifier == "tests/cutover/assert-canonical-symphony-ownership.sh" and
  (.recorded_at | fromdateiso8601) > 0
' "$CANONICAL_TARGET" >/dev/null || fail "canonical target ownership record is incomplete"

(cd "$EVIDENCE_DIR" && shasum -a 256 -c "$(basename "$RUNTIME_DISPOSITION_SUM")") >/dev/null \
  || fail "runtime disposition checksum does not match"
jq -e '
  .schema == "e11-us100-runtime-disposition-v1" and
  .status == "complete" and .reviewed == true and
  .archive.worktrees_verified_before_removal == 15 and
  .archive.all_patch_identities_matched == true and
  .archive.all_restore_rehearsals_passed == true and
  .archive.untracked_files_before_removal == 0 and
  .removal.registered_worktrees_removed == 15 and
  .removal.symphony_branches_removed == 0 and
  .removal.symphony_branches_preserved == 15 and
  .removal.impeccable_files_removed == 2 and
  .removal.changeset_files_removed == 0 and
  .post_cleanup.registered_legacy_worktrees == 0 and
  .post_cleanup.impeccable_files == 0 and
  .post_cleanup.changeset_files == 0 and
  .post_cleanup.audit_status == "pass" and
  (.recorded_at | fromdateiso8601) > 0
' "$RUNTIME_DISPOSITION" >/dev/null || fail "runtime disposition record is incomplete"
"$ROOT_DIR/tests/cutover/audit-us100-runtime-disposition.sh" --expect-clean >/dev/null \
  || fail "runtime disposition does not match the active checkout"

# Pin the exact public Symphony release already independently downloaded and
# checksum-verified. A release URL or tag alone is not sufficient evidence.
jq -e '
  .schema == "e11-us100-symphony-release-v1" and
  .repository == "hoangnb24/symphony" and
  .tag == "symphony-v0.1.1" and
  .source_commit == "2f0b257a0b145287c4b3b9e254fea5eca454c228" and
  .draft == false and .prerelease == false and
  (.published_at | fromdateiso8601) > 0 and
  (.release_url | test("^https://github.com/hoangnb24/symphony/releases/tag/symphony-v0\\.1\\.1$")) and
  .candidate_run == 29198353648 and
  .download_verification.all_sidecars_passed == true and
  (.download_verification.verified_at | fromdateiso8601) > 0 and
  ([.archives[] | {key: .platform, value: .sha256}] | from_entries) == {
    "linux-arm64": "c70e45a9a933b76717b36e2a7db2e41d639408c4d6a3aba68af54be3d7e8bdb5",
    "linux-x64": "866a4cc08f92584d3d0a7247fa71dd4e5ee86f91bea69e0438a1bb75db4af684",
    "mac-arm64": "3bc2c669e4da9a30cec983835f0c511ea5adc48e1f76980dded768170295ffa7",
    "mac-x64": "b876ee1c9246de2e4e8bd12ec5253af95d288885f1ce7c94b40944ebddb0c224",
    "windows-x64": "d09e1d33b60402669a95a77001495e56560ce48f7fb586f82f35c85d5e80ed9d"
  } and
  ([.archives[].sha256] | length) == 5 and ([.archives[].sha256] | unique | length) == 5
' "$RELEASE" >/dev/null || fail "Symphony release identity or archive checksums do not match the approved release"

# Pre-merge smoke is historical proof from the initial v0.1.0 release. Keep it
# pinned independently; readiness must use the later exact compatible release.
PREMERGE_SYMPHONY_SHA="$(jq -r '.symphony.archive_sha256' "$PREMERGE")"
test "$PREMERGE_SYMPHONY_SHA" = "eb9d56bde05581c1fba56984937159218d4829b339385eb4ebafce835c049d90" \
  || fail "pre-merge smoke is not bound to the historical Symphony v0.1.0 archive"
SYMPHONY_RELEASE_SHA="$(jq -r '.archives[] | select(.platform == "mac-arm64") | .sha256' "$RELEASE")"
test "$SYMPHONY_RELEASE_SHA" = "3bc2c669e4da9a30cec983835f0c511ea5adc48e1f76980dded768170295ffa7" \
  || fail "approved Symphony v0.1.1 smoke archive is missing"

TESTED_CANDIDATE_COMMIT="$(jq -r '.scenarios[] | select(.name == "cleaned-develop-candidate") | .harness_source_commit' "$PREMERGE")"
[[ "$TESTED_CANDIDATE_COMMIT" =~ ^[0-9a-f]{40}$ ]] \
  || fail "cleaned develop candidate does not name its tested source commit"
git -C "$ROOT_DIR" cat-file -e "$TESTED_CANDIDATE_COMMIT^{commit}" 2>/dev/null \
  || fail "tested candidate commit is not present in repository history"
git -C "$ROOT_DIR" merge-base --is-ancestor "$TESTED_CANDIDATE_COMMIT" HEAD \
  || fail "tested candidate commit is not an ancestor of the current candidate"
while IFS= read -r changed_path; do
  case "$changed_path" in
    docs/stories/epics/E11-symphony-repository-separation/US-100-cutover-and-post-separation-audit/*|\
    scripts/verify-e11-us100.sh|\
    tests/boundary/symphony-history-allowlist.tsv|\
    tests/core/assert-durable-state-boundary.sh|\
    tests/cutover/*) ;;
    *) fail "current candidate contains an untested runtime delta after $TESTED_CANDIDATE_COMMIT: $changed_path" ;;
  esac
done < <(git -C "$ROOT_DIR" diff --name-only "$TESTED_CANDIDATE_COMMIT"..HEAD)

# The develop-candidate gate uses the released Symphony artifact against both
# the immutable protocol control and the cleaned source candidate. This is not
# a substitute for the later cleaned Harness release tuple.
jq -e --arg symphony_sha "$PREMERGE_SYMPHONY_SHA" --arg candidate_commit "$TESTED_CANDIDATE_COMMIT" '
  .schema == "e11-us100-premerge-smokes-v1" and
  (.recorded_at | fromdateiso8601) > 0 and
  .symphony.tag == "symphony-v0.1.0" and
  .symphony.source_commit == "2357bc4f333a12794f975a46dbc0df96599fe4c0" and
  .symphony.archive_sha256 == $symphony_sha and
  (.scenarios | length) == 2 and
  ([.scenarios[].name] | sort) == ["cleaned-develop-candidate","initial-protocol-release"] and
  (.scenarios[] | select(.name == "initial-protocol-release") |
    .harness_label == "harness-cli-v0.1.14" and
    .harness_cli_sha256 == "0adcd5360cd636c189fe0cd958e5b73261f7012a4e43631f08c61269c785caf9") and
  (.scenarios[] | select(.name == "cleaned-develop-candidate") |
    .harness_source_commit == $candidate_commit and
    .harness_label == "harness-cli-v0.1.14-candidate") and
  all(.scenarios[];
    .status == "pass" and (.harness_cli_sha256 | test("^[0-9a-f]{64}$")) and
    (.run_id | strings | length) > 0 and
    (.logical_before | test("^[0-9a-f]{64}$")) and
    (.logical_after | test("^[0-9a-f]{64}$")) and
    .logical_before != .logical_after) and
  .assertions.checksum_verified == true and
  .assertions.outside_both_clones == true and
  .assertions.doctor == true and .assertions.work_list == true and
  .assertions.prepare_only == true and .assertions.deterministic_execution == true and
  .assertions.web_health_and_assets == true and
  .assertions.sync_first_operations == 3 and .assertions.sync_second_operations == 0
' "$PREMERGE" >/dev/null || fail "pre-merge released cross-repository smoke evidence is incomplete"

DB="${HARNESS_DB_PATH:-$ROOT_DIR/harness.db}"
need "$DB"
test "$(sqlite3 "$DB" "SELECT count(*) FROM story WHERE id='US-100' AND status IN ('in_progress','implemented');")" = 1 \
  || fail "US-100 must be in_progress for completion or already implemented after passing the final gate"

ALLOW_AUDIT_STORY_ID=US-100 "$ROOT_DIR/tests/core/assert-durable-state-boundary.sh" >/dev/null \
  || fail "source durable-state ownership boundary failed"

for path in .agents .codex; do
  test ! -e "$ROOT_DIR/$path" || fail "active checkout still contains $path"
done
if find "$ROOT_DIR/.harness/changesets" -type f -print -quit 2>/dev/null | grep -q .; then
  fail "active checkout contains live .harness/changesets files"
fi

if [[ "$MODE" == "--develop-candidate" ]]; then
  echo "US-100 develop candidate passed; runtime cleanup and compatible Symphony release are verified; readiness/final gates remain separate"
  exit 0
fi

need "$CUTOVER"

# Readiness describes the complete cutover tuple and is the authoritative
# evidence required for final completion.
jq -e --arg symphony_sha "$SYMPHONY_RELEASE_SHA" '
  def sha256: type == "string" and test("^[0-9a-f]{64}$");
  def commit: type == "string" and test("^[0-9a-f]{40}$");
  def required_capabilities: [
    "stories.read.v1","stories.write.v1","work-graph.read.v1",
    "story-dependencies.read-write.v1","story-hierarchy.read-write.v1",
    "changesets.apply.v1","changesets.status-sha.v1","isolated-db.v1",
    "isolated-db-snapshot.v1","semantic-operation-log.v1"
  ];
  def exact_platforms:
    ([.[].platform] | sort) == (["linux-arm64","linux-x64","mac-arm64","mac-x64","windows-x64"] | sort) and
    length == 5 and ([.[].sha256] | unique | length) == 5 and
    all(.[]; (.sha256 | sha256) and .verified == true and .sidecar_verified == true);
  def contract($version):
    .protocol_version == 1 and .cli_version == $version and
    .schema_minimum == 1 and .schema_maximum == 13 and .database_schema_version == 13 and
    (required_capabilities - .capabilities | length) == 0;
  . as $record |
  (.harness.cleaned_core.tag | sub("^harness-cli-v"; "")) as $clean_version |
  .schema == "e11-us100-cutover-readiness-v1" and
  .symphony.tag == "symphony-v0.1.1" and
  .symphony.source_commit == "2f0b257a0b145287c4b3b9e254fea5eca454c228" and
  .harness.initial_protocol.tag == "harness-cli-v0.1.14" and
  .harness.initial_protocol.source_commit == "d2f89eeabe8d01df95fd19cd6ba981b01a71730f" and
  .harness.initial_protocol.tag_peeled_commit == .harness.initial_protocol.source_commit and
  .harness.initial_protocol.release_verified == true and
  (.harness.initial_protocol.release_metadata_sha256 | sha256) and
  (.harness.initial_protocol.archives | exact_platforms) and
  (.harness.cleaned_core.tag | test("^harness-cli-v[0-9]+\\.[0-9]+\\.[0-9]+$")) and
  (.harness.cleaned_core.source_commit | commit) and
  .harness.cleaned_core.tag_peeled_commit == .harness.cleaned_core.source_commit and
  .harness.cleaned_core.release_verified == true and
  (.harness.cleaned_core.published_at | fromdateiso8601) > 0 and
  (.harness.cleaned_core.release_url | test("^https://github.com/hoangnb24/repository-harness/releases/tag/harness-cli-v[0-9]+\\.[0-9]+\\.[0-9]+$")) and
  (.harness.cleaned_core.release_metadata_sha256 | sha256) and
  (.harness.cleaned_core.archives | exact_platforms) and
  (.contracts.initial_protocol | contract("0.1.14")) and
  (.contracts.cleaned_core | contract($clean_version)) and
  .smokes.initial_protocol.status == "pass" and
  .smokes.initial_protocol.symphony_archive_sha256 == $symphony_sha and
  (.smokes.initial_protocol.harness_platform | strings | length) > 0 and
  (.smokes.initial_protocol.harness_cli_sha256 as $sha |
    any($record.harness.initial_protocol.archives[]; .platform == $record.smokes.initial_protocol.harness_platform and .sha256 == $sha)) and
  (.smokes.initial_protocol.output_sha256 | sha256) and
  .smokes.cleaned_core.status == "pass" and
  .smokes.cleaned_core.symphony_archive_sha256 == $symphony_sha and
  (.smokes.cleaned_core.harness_platform | strings | length) > 0 and
  (.smokes.cleaned_core.harness_cli_sha256 as $sha |
    any($record.harness.cleaned_core.archives[]; .platform == $record.smokes.cleaned_core.harness_platform and .sha256 == $sha)) and
  (.smokes.cleaned_core.output_sha256 | sha256) and
  .smokes.initial_protocol.symphony_archive_sha256 == .smokes.cleaned_core.symphony_archive_sha256 and
  .clean_harness_install.status == "pass" and
  .clean_harness_install.tag == .harness.cleaned_core.tag and
  (.clean_harness_install.output_sha256 | sha256) and
  .canonical_ownership_audit.status == "pass" and
  (.canonical_ownership_audit.output_sha256 | sha256) and
  (.canonical_ownership_audit.commands | type) == "array" and
  (["matrix","backlog","tools","audit","improvement-health","propose"] - .canonical_ownership_audit.commands | length) == 0 and
  .runtime_disposition.status == "complete" and .runtime_disposition.reviewed == true and
  (.runtime_disposition.manifest_sha256 | sha256) and
  ([.evidence_files[].kind] | sort) == ([
    "clean_install","cleaned_contract","cleaned_smoke","initial_contract",
    "initial_smoke","ownership_audit","runtime_disposition"
  ] | sort) and
  (.evidence_files | length) == 7 and
  all(.evidence_files[];
    (.path | strings | length) > 0 and
    (.path | startswith("/") | not) and
    (.path | test("(^|/)\\.\\.(/|$)") | not) and
    (.sha256 | sha256)) and
  (.recorded_at | fromdateiso8601) > 0
' "$CUTOVER" >/dev/null || fail "cutover readiness record is incomplete"

while IFS=$'\t' read -r evidence_path expected_sha; do
  need "$EVIDENCE_DIR/$evidence_path"
  actual_sha="$(shasum -a 256 "$EVIDENCE_DIR/$evidence_path" | awk '{print $1}')"
  test "$actual_sha" = "$expected_sha" \
    || fail "cutover evidence checksum does not match: $evidence_path"
done < <(jq -r '.evidence_files[] | [.path,.sha256] | @tsv' "$CUTOVER")

test ! -e "$ROOT_DIR/.impeccable" || fail "active checkout still contains .impeccable"

if [[ "$MODE" == "--readiness" ]]; then
  echo "US-100 cutover readiness passed"
  exit 0
fi

echo "US-100 final cutover gate passed; explicit story completion may now run"
