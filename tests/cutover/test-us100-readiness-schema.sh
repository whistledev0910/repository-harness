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

platforms='["linux-arm64","linux-x64","mac-arm64","mac-x64","windows-x64"]'
capabilities='["stories.read.v1","stories.write.v1","work-graph.read.v1","story-dependencies.read-write.v1","story-hierarchy.read-write.v1","changesets.apply.v1","changesets.status-sha.v1","isolated-db.v1","isolated-db-snapshot.v1","semantic-operation-log.v1"]'
jq -n --argjson platforms "$platforms" --argjson capabilities "$capabilities" '
  def archives: [$platforms | to_entries[] | {platform:.value,sha256:(((.key + 1 | tostring) + ("a" * 63))[:64]),verified:true,sidecar_verified:true}];
  def contract($version): {protocol_version:1,cli_version:$version,schema_minimum:1,schema_maximum:13,database_schema_version:13,capabilities:$capabilities};
  {
    schema:"e11-us100-cutover-readiness-v1",
    symphony:{tag:"symphony-v0.1.1",source_commit:"2f0b257a0b145287c4b3b9e254fea5eca454c228"},
    harness:{
      initial_protocol:{tag:"harness-cli-v0.1.14",source_commit:"d2f89eeabe8d01df95fd19cd6ba981b01a71730f",tag_peeled_commit:"d2f89eeabe8d01df95fd19cd6ba981b01a71730f",release_verified:true,release_metadata_sha256:("b"*64),archives:archives},
      cleaned_core:{tag:"harness-cli-v0.1.15",source_commit:("1"*40),tag_peeled_commit:("1"*40),release_verified:true,published_at:"2026-07-12T12:00:00Z",release_url:"https://github.com/hoangnb24/repository-harness/releases/tag/harness-cli-v0.1.15",release_metadata_sha256:("c"*64),archives:archives}
    },
    contracts:{initial_protocol:contract("0.1.14"),cleaned_core:contract("0.1.15")},
    smokes:{
      initial_protocol:{status:"pass",symphony_archive_sha256:"3bc2c669e4da9a30cec983835f0c511ea5adc48e1f76980dded768170295ffa7",harness_platform:"mac-arm64",harness_cli_sha256:((3|tostring)+("a"*63)),output_sha256:("4"*64)},
      cleaned_core:{status:"pass",symphony_archive_sha256:"3bc2c669e4da9a30cec983835f0c511ea5adc48e1f76980dded768170295ffa7",harness_platform:"mac-arm64",harness_cli_sha256:((3|tostring)+("a"*63)),output_sha256:("6"*64)}
    },
    clean_harness_install:{status:"pass",tag:"harness-cli-v0.1.15",output_sha256:("7"*64)},
    canonical_ownership_audit:{status:"pass",output_sha256:("8"*64),commands:["matrix","backlog","tools","audit","improvement-health","propose"]},
    runtime_disposition:{status:"complete",reviewed:true,manifest_sha256:("9"*64)},
    evidence_files:[
      {kind:"clean_install",path:"proof/clean-install.json",sha256:("1"*64)},
      {kind:"cleaned_contract",path:"proof/cleaned-contract.json",sha256:("2"*64)},
      {kind:"cleaned_smoke",path:"proof/cleaned-smoke.json",sha256:("3"*64)},
      {kind:"initial_contract",path:"proof/initial-contract.json",sha256:("4"*64)},
      {kind:"initial_smoke",path:"proof/initial-smoke.json",sha256:("5"*64)},
      {kind:"ownership_audit",path:"proof/ownership-audit.json",sha256:("6"*64)},
      {kind:"runtime_disposition",path:"proof/runtime-disposition.json",sha256:("7"*64)}
    ],
    recorded_at:"2026-07-12T12:00:00Z"
  }
' >"$tmp/base.json"

# The complete valid shape must reach evidence-file verification. This guards
# the jq binding/precedence around the cleaned release version before negative
# schema mutations are exercised.
case_dir="$tmp/valid-shape"
make_evidence "$case_dir"
cp "$tmp/base.json" "$case_dir/cutover-readiness.json"
if US100_EVIDENCE_DIR="$case_dir" "$ROOT_DIR/scripts/verify-e11-us100.sh" --readiness >"$tmp/out" 2>"$tmp/err"; then
  echo "synthetic readiness unexpectedly passed without referenced proof files" >&2
  exit 1
fi
grep -q 'required evidence is missing:.*proof/clean-install.json' "$tmp/err" || {
  echo "valid readiness shape did not reach evidence-file verification" >&2
  cat "$tmp/err" >&2
  exit 1
}

expect_schema_failure() {
  local filter=$1 description=$2 case_dir="$tmp/case"
  rm -rf "$case_dir"
  make_evidence "$case_dir"
  jq "$filter" "$tmp/base.json" >"$case_dir/cutover-readiness.json"
  if US100_EVIDENCE_DIR="$case_dir" "$ROOT_DIR/scripts/verify-e11-us100.sh" --readiness >"$tmp/out" 2>"$tmp/err"; then
    echo "US-100 readiness verifier accepted $description" >&2
    exit 1
  fi
  grep -q 'cutover readiness record is incomplete' "$tmp/err" || {
    echo "readiness negative did not reach the schema gate: $description" >&2
    cat "$tmp/err" >&2
    exit 1
  }
}

expect_schema_failure '.harness.cleaned_core.archives[1].platform = .harness.cleaned_core.archives[0].platform' "duplicate platforms"
expect_schema_failure '.contracts.cleaned_core.capabilities = []' "an empty capability assertion"
expect_schema_failure '.smokes.cleaned_core = {status:"pass"}' "a status-only smoke"
expect_schema_failure '.canonical_ownership_audit = {status:"pass"}' "a status-only ownership audit"
expect_schema_failure '.harness.cleaned_core.archives[0].sidecar_verified = false' "an unverified checksum sidecar"
expect_schema_failure '.symphony = {tag:"symphony-v9.9.9",source_commit:("f"*40)}' "an arbitrary Symphony release substitution"

echo "US-100 readiness schema rejects duplicate artifacts, incomplete contracts, and status-only proof"
