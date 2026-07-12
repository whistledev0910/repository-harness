#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
mkdir -p "$temp/source/scripts" "$temp/fresh/scripts"
cp -R "$root/scripts/schema" "$temp/source/scripts/schema"
cp -R "$root/scripts/schema" "$temp/fresh/scripts/schema"
cli="$root/target/debug/harness-cli"
cargo build --quiet --manifest-path "$root/Cargo.toml" -p harness-cli
HARNESS_REPO_ROOT="$temp/source" HARNESS_DB_PATH="$temp/source/harness.db" "$cli" init >/dev/null
HARNESS_REPO_ROOT="$temp/fresh" HARNESS_DB_PATH="$temp/fresh/harness.db" "$cli" init >/dev/null

sqlite3 "$temp/source/harness.db" <<'SQL'
INSERT INTO story(id,title,risk_lane,status) VALUES
  ('CORE-1','Retained','normal','planned'),
  ('MOVE-1','Archived','normal','planned');
INSERT INTO intake(id,input_type,summary,risk_lane,story_id,uid) VALUES
  (10,'maintenance','core','normal','CORE-1','ink_core'),
  (11,'maintenance','move','normal','MOVE-1','ink_move');
INSERT INTO trace(id,task_summary,agent,outcome,intake_id,story_id,uid)
  VALUES(20,'core trace','agent','completed',10,'CORE-1','trc_core');
INSERT INTO tool(name,provider,command,description,responsibility,status,checked_at)
  VALUES('core-tool','custom','true','core','Verification','present','2026-01-01 00:00:00');
INSERT INTO changeset_applied(id,path,content_sha256) VALUES('legacy','old','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
SQL

python3 - "$root" "$temp/source/harness.db" "$temp/dispositions.json" <<'PY'
import importlib.util,json,pathlib,sys
root=pathlib.Path(sys.argv[1]); path=root/'scripts/e11-us097-inventory.py'
spec=importlib.util.spec_from_file_location('inventory',path); module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
inventory=module.inventory_database(pathlib.Path(sys.argv[2])); rows=[]
for table,detail in inventory['tables'].items():
  for identity in detail['identities']:
    action='derive' if table in {'schema_version','changeset_applied'} else ('archive-only' if table in {'story','intake'} and 'MOVE-1' in identity or identity.endswith('11') or identity.endswith('"ink_move"') else 'retain-core')
    rows.append({'table':table,'identity':identity,'action':action,'owner':'fixture','reason':'fixture'})
pathlib.Path(sys.argv[3]).write_text(json.dumps({'rows':rows}))
PY

python3 "$root/scripts/e11-us097-prepare-core.py" \
  --repo-root "$root" \
  --source-db "$temp/source/harness.db" \
  --dispositions "$temp/dispositions.json" \
  --output-db "$temp/fresh/harness.db" \
  --report "$temp/report.json" >/dev/null
test "$(sqlite3 "$temp/fresh/harness.db" "select group_concat(id) from story")" = CORE-1
test "$(sqlite3 "$temp/fresh/harness.db" "select group_concat(uid) from intake")" = ink_core
test "$(sqlite3 "$temp/fresh/harness.db" "select group_concat(uid) from trace")" = trc_core
test "$(sqlite3 "$temp/fresh/harness.db" "select status || ':' || coalesce(checked_at,'null') from tool")" = unknown:null
test "$(sqlite3 "$temp/fresh/harness.db" 'select count(*) from changeset_applied')" = 0
jq -e '.copied_row_count == 4 and .changeset_applied_count == 0 and .tool_presence_reset' "$temp/report.json" >/dev/null

echo "US-097 fresh-core preparation tests passed"
