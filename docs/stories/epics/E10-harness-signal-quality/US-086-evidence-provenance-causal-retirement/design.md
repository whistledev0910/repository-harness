# Design

## Domain Model

Evidence has an explicit provenance: `production`, `benchmark`, `smoke`,
`test_fixture`, or `imported_legacy`. Existing evidence defaults
conservatively to `production` unless explicitly reclassified.

A proposal rule may expose a deterministic current-state resolver. A resolver
can suppress evidence only when it proves the exact proposed capability is now
satisfied. The suppression explanation records the rule and observed state.

## Application Flow

```text
raw evidence
  -> filter default proposal provenance
  -> group stable evidence
  -> evaluate rule-specific current-state resolver
  -> classify actionable, suppressed, or recurrence
  -> print explanation without deleting evidence
```

## Interface Contract

- Trace and intervention writes accept optional provenance and default to
  `production`.
- Proposal preview excludes `smoke` and `test_fixture` evidence by default.
- `propose --show-suppressed` explains provenance or current-state retirement.
- An explicit inspection option may include non-production evidence without
  making it actionable.

## Data Model

Use an additive migration and replayable semantic operations. Provenance must
survive fresh-database rebuilds. Current-state suppression may be derived at
query time and must not rewrite raw evidence.

## Observability

Proposal explanations name the evidence ids, provenance filter, resolver, and
state responsible for suppression.

## Alternatives Considered

1. Delete smoke traces. Rejected because it destroys test and audit history.
2. Treat a human rejection as the only cleanup mechanism. Rejected because the
   same known-obsolete signal would consume operator attention in every fresh
   repository until manually decided.
3. Apply generic text similarity to infer resolution. Rejected because it is
   not deterministic enough for replay-safe lifecycle behavior.
