#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_EVIDENCE="$ROOT_DIR/docs/stories/epics/E11-symphony-repository-separation/US-100-cutover-and-post-separation-audit/evidence"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

make_evidence() {
  local destination=$1
  mkdir -p "$destination"
  cp "$SOURCE_EVIDENCE/symphony-release.json" "$destination/"
  cp "$SOURCE_EVIDENCE/premerge-released-cross-repo-smokes.json" "$destination/"
  cp "$SOURCE_EVIDENCE/rollback-rehearsal.json" "$destination/"
  cp "$SOURCE_EVIDENCE/rollback-rehearsal.json.sha256" "$destination/"
  cp "$SOURCE_EVIDENCE/canonical-target-ownership.json" "$destination/"
  cp "$SOURCE_EVIDENCE/canonical-target-ownership.json.sha256" "$destination/"
  cp "$SOURCE_EVIDENCE/runtime-disposition.json" "$destination/"
  cp "$SOURCE_EVIDENCE/runtime-disposition.json.sha256" "$destination/"
}

expect_develop_failure() {
  local evidence=$1 description=$2
  if US100_EVIDENCE_DIR="$evidence" "$ROOT_DIR/scripts/verify-e11-us100.sh" --develop-candidate >"$tmp/out" 2>"$tmp/err"; then
    echo "US-100 verifier accepted $description" >&2
    exit 1
  fi
}

case_dir="$tmp/wrong-symphony-archive"
make_evidence "$case_dir"
jq '.symphony.archive_sha256 = ("0" * 64)' "$case_dir/premerge-released-cross-repo-smokes.json" >"$case_dir/new"
mv "$case_dir/new" "$case_dir/premerge-released-cross-repo-smokes.json"
expect_develop_failure "$case_dir" "a smoke detached from the released Symphony archive"

case_dir="$tmp/substituted-symphony-release"
make_evidence "$case_dir"
jq '.tag = "symphony-v9.9.9" | .source_commit = ("f" * 40) | .release_url = "https://github.com/hoangnb24/symphony/releases/tag/symphony-v9.9.9"' \
  "$case_dir/symphony-release.json" >"$case_dir/new"
mv "$case_dir/new" "$case_dir/symphony-release.json"
expect_develop_failure "$case_dir" "an arbitrary Symphony release substitution"

case_dir="$tmp/wrong-initial-cli"
make_evidence "$case_dir"
jq '(.scenarios[] | select(.name == "initial-protocol-release") | .harness_cli_sha256) = ("0" * 64)' \
  "$case_dir/premerge-released-cross-repo-smokes.json" >"$case_dir/new"
mv "$case_dir/new" "$case_dir/premerge-released-cross-repo-smokes.json"
expect_develop_failure "$case_dir" "an unapproved initial Harness CLI"

case_dir="$tmp/no-state-transition"
make_evidence "$case_dir"
jq '(.scenarios[] | select(.name == "cleaned-develop-candidate") | .logical_after) = .scenarios[1].logical_before' \
  "$case_dir/premerge-released-cross-repo-smokes.json" >"$case_dir/new"
mv "$case_dir/new" "$case_dir/premerge-released-cross-repo-smokes.json"
expect_develop_failure "$case_dir" "a smoke with no logical state transition"

case_dir="$tmp/unknown-candidate"
make_evidence "$case_dir"
jq '(.scenarios[] | select(.name == "cleaned-develop-candidate") | .harness_source_commit) = ("0" * 40)' \
  "$case_dir/premerge-released-cross-repo-smokes.json" >"$case_dir/new"
mv "$case_dir/new" "$case_dir/premerge-released-cross-repo-smokes.json"
expect_develop_failure "$case_dir" "an unknown candidate commit"

echo "US-100 develop verifier rejects substituted releases, detached artifacts, weak state proof, and untested candidates"
