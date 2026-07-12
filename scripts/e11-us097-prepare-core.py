#!/usr/bin/env python3
"""Populate a normally migrated fresh Harness DB with retained core rows."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sqlite3
from pathlib import Path


INSERT_ORDER = (
    "story",
    "backlog",
    "decision",
    "intake",
    "tool",
    "audit_evidence_episode",
    "legacy_evidence_snapshot",
    "trace",
    "intervention",
    "backlog_outcome_observation",
    "proposal_evidence_link",
    "story_backlog_link",
    "story_dependency",
    "story_hierarchy",
)


def load_inventory_module(root: Path):
    path = root / "scripts/e11-us097-inventory.py"
    spec = importlib.util.spec_from_file_location("e11_us097_inventory", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load inventory module: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def quote(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--source-db", type=Path, required=True)
    parser.add_argument("--dispositions", type=Path, required=True)
    parser.add_argument("--output-db", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    root = args.repo_root.resolve()
    inventory_module = load_inventory_module(root)
    source_inventory = inventory_module.inventory_database(args.source_db)
    ledger = json.loads(args.dispositions.read_text())
    retained = {
        (row["table"], row["identity"])
        for row in ledger["rows"]
        if row["action"] == "retain-core"
    }
    if not args.output_db.is_file():
        raise ValueError("output DB must first be created through normal Harness migrations")
    source = sqlite3.connect(f"file:{args.source_db.resolve()}?mode=ro&immutable=1", uri=True)
    source.row_factory = sqlite3.Row
    output = sqlite3.connect(args.output_db)
    output.execute("PRAGMA foreign_keys=ON")
    copied = {}
    try:
        output.execute("BEGIN IMMEDIATE")
        for table in INSERT_ORDER:
            source_detail = source_inventory["tables"].get(table)
            if source_detail is None:
                raise ValueError(f"source table is missing: {table}")
            output_columns = [row[1] for row in output.execute(f"PRAGMA table_info({quote(table)})")]
            if output_columns != source_detail["columns"]:
                raise ValueError(f"source/fresh schema columns differ for {table}")
            selected = [
                row for row in source_detail["rows"]
                if (table, row["identity"]) in retained
            ]
            placeholders = ",".join("?" for _ in output_columns)
            column_sql = ",".join(quote(column) for column in output_columns)
            for row in selected:
                values = [row["values"][column] for column in output_columns]
                output.execute(
                    f"INSERT INTO {quote(table)} ({column_sql}) VALUES ({placeholders})",
                    values,
                )
            copied[table] = len(selected)
        # Presence is an epoch-derived cache. Keep provider identity/config but
        # require an explicit scan in the new epoch.
        output.execute("UPDATE tool SET status='unknown', checked_at=NULL")
        violations = list(output.execute("PRAGMA foreign_key_check"))
        if violations:
            raise ValueError(f"fresh core foreign-key violations: {violations}")
        output.commit()
    except Exception:
        output.rollback()
        raise
    finally:
        source.close()
        output.close()

    fresh_inventory = inventory_module.inventory_database(args.output_db)
    retained_count = sum(copied.values())
    actual_non_derived = sum(
        detail["count"] for table, detail in fresh_inventory["tables"].items()
        if table not in {"schema_version", "changeset_applied"}
    )
    if actual_non_derived != retained_count:
        raise ValueError(
            f"fresh core row count differs: copied {retained_count}, found {actual_non_derived}"
        )
    report = {
        "version": 1,
        "source_db_sha256": source_inventory["sha256"],
        "fresh_db_sha256": fresh_inventory["sha256"],
        "normal_migration_schema_versions": fresh_inventory["tables"]["schema_version"]["count"],
        "changeset_applied_count": fresh_inventory["tables"]["changeset_applied"]["count"],
        "copied_by_table": copied,
        "copied_row_count": retained_count,
        "foreign_key_violations": fresh_inventory["foreign_key_violations"],
        "tool_presence_reset": all(
            row["values"]["status"] == "unknown" and row["values"]["checked_at"] is None
            for row in fresh_inventory["tables"]["tool"]["rows"]
        ),
    }
    if report["changeset_applied_count"] != 0 or not report["tool_presence_reset"]:
        raise ValueError("derived epoch state was copied instead of recomputed/reset")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(f"US-097 fresh core prepared: {retained_count} retained rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
