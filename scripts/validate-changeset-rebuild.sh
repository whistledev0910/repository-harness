#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HARNESS_DB_PATH="$TMP_DIR/harness.db" \
  "$ROOT_DIR/scripts/bin/harness-cli" db rebuild --from "$ROOT_DIR/.harness/changesets" >/dev/null

expected_ids=(
  US-028 US-029 US-030 US-031 US-032 US-033 US-034 US-035 US-036 US-037
  US-038 US-039 US-040 US-041 US-042 US-043 US-044 US-045 US-046 US-047
  US-048 US-049 US-050 US-051 US-052 US-053 US-054 US-055 US-056 US-057
  US-058 US-059 US-060 US-061 US-062 US-063 US-SYM-001
)

for id in "${expected_ids[@]}"; do
  count="$(sqlite3 "$TMP_DIR/harness.db" "SELECT COUNT(*) FROM story WHERE id='$id';")"
  if [[ "$count" != "1" ]]; then
    echo "missing rebuilt story row: $id" >&2
    exit 1
  fi
done

planned_count="$(
  sqlite3 "$TMP_DIR/harness.db" \
    "SELECT COUNT(*) FROM story WHERE id IN ('US-061', 'US-063') AND status='planned';"
)"
if [[ "$planned_count" != "2" ]]; then
  echo "expected US-061 and US-063 to rebuild as planned" >&2
  exit 1
fi

echo "changeset rebuild restored ${#expected_ids[@]} Symphony story rows"
