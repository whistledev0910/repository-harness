# Exec Plan

## Goal

Prevent synthetic and deterministically resolved evidence from competing with
real improvement work while preserving history and recurrence semantics.

## Scope

In scope:

- Additive evidence provenance.
- Replay-safe trace/intervention provenance writes.
- Default proposal filtering.
- Rule-specific current-state retirement.
- Suppression and recurrence tests and docs.

Out of scope:

- Queue-health presentation and trace-health aggregation.
- Automatic proposal decisions.

## Risk Classification

Risk flags:

- Data model.
- Existing behavior.
- Public CLI contracts.
- Weak proof around historical evidence classification.

Hard gates:

- Durable lifecycle and semantic replay behavior.

## Work Phases

1. Add failing provenance and current-state retirement tests.
2. Add schema/domain/repository support and replay operations.
3. Add CLI inputs and proposal filtering.
4. Add deterministic resolver support for equipped validation capabilities.
5. Validate suppression, recurrence, and fresh rebuild.
6. Update current-behavior documentation.

## Stop Conditions

Pause for human confirmation if implementation would rewrite historical
evidence, use fuzzy resolution, or weaken explicit proposal decisions.
