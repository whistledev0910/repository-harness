# US-088 Lane-Aware Trace Health

## Status

planned

## Lane

normal

## Product Contract

Operators can inspect aggregate trace-tier compliance for a bounded time or
count window, evaluated against each trace's applicable lane and historical
contract.

## Relevant Product Docs

- `docs/TRACE_SPEC.md`
- `docs/HARNESS_MATURITY.md`

## Acceptance Criteria

- A query summarizes Detailed, Standard, Minimal, and lane-invalid traces.
- Each invalid row lists concrete missing fields.
- Tiny traces are not required to meet Standard unless friction or Harness
  policy changes require it.
- Historical traces created before a field or rule existed are identified
  separately rather than reported as current regressions.
- Output supports a recent-count window and deterministic machine-readable form.

## Design Notes

- Query: `query trace-health`.
- Reuse the existing individual trace scorer instead of duplicating tier rules.
- Depends on `US-086` so synthetic evidence can be excluded from operational
  health by default.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Lane/tier and historical-contract fixtures. |
| Integration | Aggregate counts match individual scores. |
| E2E | Text and JSON output are deterministic. |
| Platform | CLI help documents filters. |
| Release | Workspace tests, fmt, clippy, rebuild. |

## Harness Delta

Complete the operational portion of backlog item `#3` and update H3 evidence.

## Evidence

Pending implementation.
