# US-087 Backlog Triage And Multidimensional Health

## Status

planned

## Lane

normal

## Product Contract

Operators can distinguish record integrity from improvement-flow health and can
inspect a read-only triage classification for every open backlog item.

## Relevant Product Docs

- `docs/HARNESS_AUDIT.md`
- `docs/IMPROVEMENT_PROTOCOL.md`

## Acceptance Criteria

- Health reports record integrity, improvement flow, signal quality, and queue
  age separately.
- `0/100` record entropy never implies that pending proposal decisions are
  healthy.
- Read-only triage classifies items as actionable, likely resolved, duplicate,
  superseded, needs evidence, or synthetic and explains the evidence.
- Triage never changes backlog status without an explicit operator command.

## Design Notes

- Queries: extend `query improvement-health`; add `backlog triage` or an
  equivalent read-only query.
- Domain rules: deterministic classifications and stable ordering.
- Depends on `US-086` provenance and retirement semantics.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Dimension and triage classification fixtures. |
| Integration | Live-style queue with clean integrity and pending decisions. |
| E2E | CLI snapshots remain deterministic across rebuild. |
| Platform | Help and docs describe read-only behavior. |
| Release | Workspace tests, fmt, clippy, rebuild. |

## Harness Delta

Update daily operator guidance so “record integrity” and “improvement health”
are not treated as synonyms.

## Evidence

Pending implementation.
