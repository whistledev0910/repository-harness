#!/usr/bin/env python3
"""Create and verify the read-only US-097 partition inventory.

The program deliberately opens SQLite databases in immutable read-only mode.
It never infers ownership: every source row must have an explicit disposition
in the supplied JSON manifest before ``--require-zero-unknown`` can pass.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any


REQUIRED_TABLES = {
    "intervention",
    "story_backlog_link",
    "proposal_evidence_link",
    "audit_evidence_episode",
    "backlog_outcome_observation",
    "legacy_evidence_snapshot",
    "changeset_applied",
    "schema_version",
}
IDENTITY_COLUMNS = (
    "uid", "stable_uid", "id", "name", "key", "run_id", "story_id",
    "trace_id", "intake_id", "backlog_id", "decision_id", "version",
)
TARGET_ACTIONS = {"retain-core", "move-target", "derive", "discard", "archive-only"}


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def connect_read_only(path: Path) -> sqlite3.Connection:
    if not path.is_file():
        raise ValueError(f"database does not exist: {path}")
    db = sqlite3.connect(f"file:{path.resolve()}?mode=ro&immutable=1", uri=True)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA query_only=ON")
    return db


def user_tables(db: sqlite3.Connection) -> list[str]:
    return [
        row[0]
        for row in db.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        )
    ]


def table_columns(db: sqlite3.Connection, table: str) -> list[sqlite3.Row]:
    return list(db.execute(f"PRAGMA table_info({quote_identifier(table)})"))


def quote_identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def json_value(value: Any) -> Any:
    if isinstance(value, bytes):
        return {"encoding": "hex", "value": value.hex()}
    return value


def row_identity(table: str, row: sqlite3.Row, columns: list[sqlite3.Row]) -> str:
    names = [column[1] for column in columns]
    primary = [column[1] for column in sorted(columns, key=lambda item: item[5]) if column[5]]
    stable = [
        name for name in ("uid", "stable_uid")
        if name in names and row[name] is not None and str(row[name]) != ""
    ]
    selected = stable or primary or [name for name in IDENTITY_COLUMNS if name in names]
    if not selected:
        # A table without a declared/stable key is still inventoried exactly.
        # Its canonical full-row digest is the only non-lossy identity available.
        encoded = json.dumps(
            {name: json_value(row[name]) for name in names}, sort_keys=True,
            separators=(",", ":"), ensure_ascii=False,
        ).encode()
        return f"row-sha256:{hashlib.sha256(encoded).hexdigest()}"
    parts = [f"{name}={json.dumps(json_value(row[name]), sort_keys=True, separators=(',', ':'))}" for name in selected]
    return f"{table}:" + "|".join(parts)


def inventory_database(path: Path) -> dict[str, Any]:
    db = connect_read_only(path)
    try:
        tables: dict[str, Any] = {}
        for table in user_tables(db):
            columns = table_columns(db, table)
            names = [column[1] for column in columns]
            order = [column[1] for column in sorted(columns, key=lambda item: item[5]) if column[5]]
            order_sql = ",".join(quote_identifier(name) for name in order)
            query = f"SELECT * FROM {quote_identifier(table)}"
            if order_sql:
                query += f" ORDER BY {order_sql}"
            rows = []
            identities = []
            for source_row in db.execute(query):
                identity = row_identity(table, source_row, columns)
                identities.append(identity)
                rows.append({
                    "identity": identity,
                    "values": {name: json_value(source_row[name]) for name in names},
                })
            tables[table] = {
                "schema": db.execute(
                    "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (table,)
                ).fetchone()[0],
                "columns": names,
                "count": len(rows),
                "identities": identities,
                "rows": rows,
                "foreign_keys": [dict(row) for row in db.execute(
                    f"PRAGMA foreign_key_list({quote_identifier(table)})"
                )],
            }
        fk_violations = [list(row) for row in db.execute("PRAGMA foreign_key_check")]
        return {
            "path": str(path.resolve()),
            "sha256": digest(path),
            "table_count": len(tables),
            "tables": tables,
            "foreign_key_violations": fk_violations,
        }
    finally:
        db.close()


def cutoff_manifest(directory: Path, baseline_tsv: Path) -> dict[str, Any]:
    if not directory.is_dir():
        raise ValueError(f"changeset directory does not exist: {directory}")
    current = [
        {"path": str(path), "sha256": digest(path), "size": path.stat().st_size}
        for path in sorted(directory.glob("*.changeset.jsonl")) if path.is_file()
    ]
    baseline: dict[str, str] = {}
    for number, raw in enumerate(baseline_tsv.read_text().splitlines(), 1):
        if not raw.strip():
            continue
        fields = raw.split("\t")
        if len(fields) < 5:
            raise ValueError(f"invalid baseline TSV row {number}")
        if number == 1 and fields[0] == "path" and fields[-1] == "sha256":
            continue
        name = Path(fields[0]).name
        if name in baseline:
            raise ValueError(f"duplicate baseline filename: {name}")
        baseline[name] = fields[-1]
    by_path = {Path(entry["path"]).name: entry for entry in current}
    missing = sorted(set(baseline) - set(by_path))
    changed = sorted(path for path, value in baseline.items() if path in by_path and by_path[path]["sha256"] != value)
    delta = sorted(set(by_path) - set(baseline))
    return {
        "baseline_count": len(baseline),
        "cutoff_count": len(current),
        "delta_count": len(delta),
        "missing_baseline_paths": missing,
        "changed_baseline_paths": changed,
        "delta_paths": delta,
        "files": current,
    }


def load_dispositions(path: Path) -> dict[tuple[str, str], dict[str, Any]]:
    raw = json.loads(path.read_text())
    rows = raw.get("rows")
    if not isinstance(rows, list):
        raise ValueError("disposition manifest must contain a rows array")
    result: dict[tuple[str, str], dict[str, Any]] = {}
    for index, item in enumerate(rows):
        if not isinstance(item, dict):
            raise ValueError(f"disposition row {index} is not an object")
        key = (item.get("table"), item.get("identity"))
        action = item.get("action")
        if not all(isinstance(value, str) and value for value in key):
            raise ValueError(f"disposition row {index} lacks table/identity")
        if action not in TARGET_ACTIONS:
            raise ValueError(f"disposition row {index} has invalid action: {action}")
        if key in result:
            raise ValueError(f"duplicate disposition: {key[0]} {key[1]}")
        if not isinstance(item.get("owner"), str) or not item["owner"]:
            raise ValueError(f"disposition row {index} lacks owner")
        if not isinstance(item.get("reason"), str) or not item["reason"]:
            raise ValueError(f"disposition row {index} lacks reason")
        result[key] = item
    return result


def compare(
    source: dict[str, Any], core: dict[str, Any] | None, target: dict[str, Any] | None,
    dispositions: dict[tuple[str, str], dict[str, Any]],
) -> dict[str, Any]:
    source_keys = {
        (table, identity)
        for table, details in source["tables"].items()
        for identity in details["identities"]
    }
    disposition_keys = set(dispositions)
    unknown = sorted(source_keys - disposition_keys)
    orphan = sorted(disposition_keys - source_keys)
    target_expectations = {
        key: (key[0], value.get("target_identity", key[1]))
        for key, value in dispositions.items() if value["action"] == "move-target"
    }
    expected_target = set(target_expectations.values())
    expected_core = {
        key for key, value in dispositions.items() if value["action"] == "retain-core"
    }
    derived = {
        key for key, value in dispositions.items() if value["action"] == "derive"
    }
    allowed_target_overlap = derived | {
        key for key, value in dispositions.items() if value.get("allow_target_overlap") is True
    }
    actual_core = set()
    if core:
        actual_core = {
            (table, identity)
            for table, details in core["tables"].items()
            for identity in details["identities"]
        }
    actual_target = set()
    if target:
        actual_target = {
            (table, identity)
            for table, details in target["tables"].items()
            for identity in details["identities"]
        }
    # Only moved identities are compared. Target-native rows are deliberately
    # permitted and reported separately; they do not originate in source.
    missing_target = sorted(expected_target - actual_target)
    target_native = sorted(actual_target - source_keys - expected_target)
    unexpected_source_overlap = sorted(
        (actual_target & source_keys) - expected_target - allowed_target_overlap
    )
    missing_core = sorted(expected_core - actual_core)
    core_native = sorted(actual_core - source_keys)
    unexpected_core_overlap = sorted((actual_core & source_keys) - expected_core - derived)

    # Verify that retained/moved rows do not point across a discarded or other-
    # repository disposition. Composite FKs are grouped by SQLite FK id.
    lookup: dict[tuple[str, tuple[tuple[str, Any], ...]], str] = {}
    for table, details in source["tables"].items():
        for row in details["rows"]:
            for columns in (details["columns"],):
                lookup[(table, tuple((name, json.dumps(row["values"].get(name), sort_keys=True)) for name in columns))] = row["identity"]
    disposition_fk_violations = []
    for table, details in source["tables"].items():
        grouped: dict[int, list[dict[str, Any]]] = {}
        for foreign_key in details["foreign_keys"]:
            grouped.setdefault(foreign_key["id"], []).append(foreign_key)
        for row in details["rows"]:
            child_key = (table, row["identity"])
            child_action = dispositions.get(child_key, {}).get("action")
            if child_action not in {"retain-core", "move-target"}:
                continue
            for fk_id, foreign_keys in grouped.items():
                foreign_keys.sort(key=lambda item: item["seq"])
                values = [row["values"].get(item["from"]) for item in foreign_keys]
                if all(value is None for value in values):
                    continue
                parent_table = foreign_keys[0]["table"]
                parent = source["tables"].get(parent_table)
                parent_identity = None
                if parent:
                    for parent_row in parent["rows"]:
                        if all(parent_row["values"].get(item["to"]) == value for item, value in zip(foreign_keys, values)):
                            parent_identity = parent_row["identity"]
                            break
                parent_action = dispositions.get((parent_table, parent_identity), {}).get("action") if parent_identity else None
                if parent_action != child_action:
                    disposition_fk_violations.append({
                        "table": table, "identity": row["identity"], "foreign_key_id": fk_id,
                        "parent_table": parent_table, "parent_identity": parent_identity,
                        "child_action": child_action, "parent_action": parent_action,
                    })
    action_counts = {action: 0 for action in sorted(TARGET_ACTIONS)}
    for value in dispositions.values():
        action_counts[value["action"]] += 1
    return {
        "source_row_count": len(source_keys),
        "disposition_count": len(disposition_keys),
        "action_counts": action_counts,
        "unknown_source_rows": [{"table": t, "identity": i} for t, i in unknown],
        "orphan_dispositions": [{"table": t, "identity": i} for t, i in orphan],
        "expected_target_rows": len(expected_target),
        "target_identity_mappings": [
            {
                "source_table": source[0], "source_identity": source[1],
                "target_table": target[0], "target_identity": target[1],
            }
            for source, target in sorted(target_expectations.items())
        ],
        "missing_target_rows": [{"table": t, "identity": i} for t, i in missing_target],
        "unexpected_source_target_overlap": [
            {"table": t, "identity": i} for t, i in unexpected_source_overlap
        ],
        "target_native_rows": [{"table": t, "identity": i} for t, i in target_native],
        "expected_core_rows": len(expected_core),
        "missing_core_rows": [{"table": t, "identity": i} for t, i in missing_core],
        "unexpected_source_core_overlap": [
            {"table": t, "identity": i} for t, i in unexpected_core_overlap
        ],
        "core_native_rows": [{"table": t, "identity": i} for t, i in core_native],
        "disposition_foreign_key_violations": disposition_fk_violations,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-db", type=Path, required=True)
    parser.add_argument("--target-db", type=Path)
    parser.add_argument("--core-db", type=Path)
    parser.add_argument("--changeset-dir", type=Path, required=True)
    parser.add_argument("--baseline-tsv", type=Path, required=True)
    parser.add_argument("--dispositions", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--require-zero-unknown", action="store_true")
    parser.add_argument("--require-fk-closure", action="store_true")
    parser.add_argument("--compare-uid-sets", action="store_true")
    args = parser.parse_args()

    try:
        source = inventory_database(args.source_db)
        core = inventory_database(args.core_db) if args.core_db else None
        target = inventory_database(args.target_db) if args.target_db else None
        cutoff = cutoff_manifest(args.changeset_dir, args.baseline_tsv)
        dispositions = load_dispositions(args.dispositions)
        comparison = compare(source, core, target, dispositions)
        missing_required = sorted(REQUIRED_TABLES - set(source["tables"]))
        errors = []
        if cutoff["missing_baseline_paths"] or cutoff["changed_baseline_paths"]:
            errors.append("partition cutoff does not preserve the frozen baseline")
        if missing_required:
            errors.append("required named tables are missing")
        if args.require_zero_unknown and (
            comparison["unknown_source_rows"] or comparison["orphan_dispositions"]
        ):
            errors.append("row dispositions are not exact and complete")
        if args.require_fk_closure and (
            source["foreign_key_violations"]
            or comparison["disposition_foreign_key_violations"]
            or (core and core["foreign_key_violations"])
            or (target and target["foreign_key_violations"])
        ):
            errors.append("database foreign-key closure failed")
        if args.compare_uid_sets and (
            not target
            or not core
            or comparison["missing_target_rows"]
            or comparison["unexpected_source_target_overlap"]
            or comparison["missing_core_rows"]
            or comparison["unexpected_source_core_overlap"]
        ):
            errors.append("target stable-identity comparison failed")
        report = {
            "contract_version": 1,
            "read_only": True,
            "source": source,
            "core": core,
            "target": target,
            "cutoff": cutoff,
            "required_named_tables": sorted(REQUIRED_TABLES),
            "missing_required_tables": missing_required,
            "comparison": comparison,
            "errors": errors,
            "ok": not errors,
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({
            "ok": report["ok"], "source_tables": source["table_count"],
            "source_rows": comparison["source_row_count"],
            "cutoff_files": cutoff["cutoff_count"], "errors": errors,
        }, sort_keys=True))
        return 0 if report["ok"] else 1
    except (OSError, ValueError, sqlite3.Error, json.JSONDecodeError) as error:
        print(f"US-097 inventory failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
