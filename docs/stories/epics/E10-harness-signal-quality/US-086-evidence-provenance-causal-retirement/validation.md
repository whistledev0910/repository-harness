# Validation

## Proof Strategy

Prove the exact failure chain: synthetic evidence does not create default
proposals; production evidence does; later deterministic remediation suppresses
the old proposal; later uncovered production evidence becomes recurrence; all
states survive semantic replay.

## Test Plan

| Layer | Cases |
| --- | --- |
| Unit | Provenance parsing, defaults, filtering, resolver classification. |
| Integration | Trace/intervention writes, proposal output, suppression explanation, recurrence. |
| E2E | Fresh DB applies changesets and produces the same proposal states. |
| Platform | CLI help and installed schema propagation. |
| Logs/Audit | Raw evidence remains queryable after suppression. |

## Fixtures

- Two smoke friction traces with the same normalized text.
- Two production validation-provider friction traces.
- Missing then present validation providers.
- New post-remediation production evidence.

## Commands

```text
cargo test -p harness-cli proposal_provenance
cargo test -p harness-cli proposal_current_state
scripts/validate-changeset-rebuild.sh
cargo test --workspace
cargo fmt --check
cargo clippy --workspace -- -D warnings
git diff --check
```

## Acceptance Evidence

Pending implementation.
