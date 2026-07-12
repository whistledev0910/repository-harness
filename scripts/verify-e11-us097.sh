#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

[[ ${E11_US097_FORCE_FAILURE:-0} != 1 ]] || {
  echo "intentional US-097 negative verification fixture" >&2
  exit 1
}

source_db=${E11_US097_SOURCE_DB:?set E11_US097_SOURCE_DB to the frozen source snapshot}
core_db=${E11_US097_CORE_DB:-$root/harness.db}
target_db=${E11_US097_TARGET_DB:?set E11_US097_TARGET_DB to the reconciled target DB}
legacy_changesets=${E11_US097_LEGACY_CHANGESET_DIR:?set E11_US097_LEGACY_CHANGESET_DIR to the cutoff archive}
dispositions=${E11_US097_DISPOSITIONS:?set E11_US097_DISPOSITIONS to the reviewed ledger}
inventory_output=${E11_US097_INVENTORY_OUTPUT:-$root/.harness/runs/e11-us097-verification.json}

env -u HARNESS_CHANGESET_DIR -u HARNESS_DISPOSITIONS scripts/validate-changeset-rebuild.sh
env -u HARNESS_CHANGESET_DIR -u HARNESS_DISPOSITIONS scripts/test-validate-changeset-rebuild.sh
HARNESS_SOURCE_DB="$source_db" \
HARNESS_FRESH_CORE_DB="$core_db" \
HARNESS_TARGET_DB="$target_db" \
HARNESS_CHANGESET_DIR="$legacy_changesets" \
HARNESS_DISPOSITIONS="$dispositions" \
HARNESS_INVENTORY_OUTPUT="$inventory_output" \
scripts/verify-e11-inventory.sh \
  --require-zero-unknown \
  --require-fk-closure \
  --compare-uid-sets
tests/history/test-e11-epoch-transition.sh
tests/history/assert-no-live-root-changesets.sh
tests/installer/assert-consumer-changeset-trackable.sh
cargo test -p harness-cli --locked
scripts/bin/harness-cli audit
scripts/bin/harness-cli query matrix >/dev/null
scripts/bin/harness-cli query backlog >/dev/null
scripts/bin/harness-cli query tools --summary >/dev/null
git diff --check

echo "US-097 durable history and local state partition verification passed"
