# Validation

## Proof Strategy

Prove generic operation semantics independently, then compare ownership-aware
fresh databases before atomic activation.

## Test Plan

| Layer | Cases |
| --- | --- |
| Unit | Dynamic table inventory, fixture operation versions, mixed-operation classifier, new run-ID enforcement, FK closure. |
| Integration | Synthetic changeset apply/rebuild, idempotence, crash-injected journal recovery, fresh core DB preparation, epoch-derived state, target CLI reconciliation. |
| E2E | Core and Symphony queries show only product-owned runnable work; a surviving `changed` US-096 proxy blocks source cleanup until receipt. |
| Platform | Backup/replace works with WAL reconciliation and platform path differences. |
| Performance | Record archive/rebuild duration and sizes; no requirement to replay product history in core CI. |
| Logs/Audit | Checksums, row dispositions, audit/proposal output, zero wrong-owner runnable/backlog/provider records, and only allowlisted E11 receipt proxies visible. |

## Fixtures

- Immutable archive of the 32-file frozen baseline plus a separately hashed,
  manifest-derived partition cutoff containing every post-baseline E11 file.
- Synthetic generic replay set.
- Live source DB backup.
- Temporary fresh core database and backup of the existing target database.

## Commands

```bash
shasum -a 256 -c <archive-checksums>
cargo test -p harness-cli --locked
scripts/validate-changeset-rebuild.sh
scripts/test-validate-changeset-rebuild.sh
scripts/verify-e11-inventory.sh --require-zero-unknown --require-fk-closure --compare-uid-sets
HARNESS_DB_PATH=<fresh-core> scripts/bin/harness-cli audit
HARNESS_DB_PATH=<fresh-core> scripts/bin/harness-cli query matrix
HARNESS_DB_PATH=<fresh-core> scripts/bin/harness-cli query backlog
HARNESS_DB_PATH=<fresh-core> scripts/bin/harness-cli query tools --summary
tests/history/assert-no-live-root-changesets.sh
tests/installer/assert-consumer-changeset-trackable.sh
git diff --check
```

The history assertion fails on Git/tool errors and passes only when no live
root path remains; the consumer fixture separately proves the generic tracking
rule still works.

## Acceptance Evidence

Implemented on 2026-07-12. The committed evidence index is
`docs/provenance/e11-us097-epoch-summary.json`; its sidecar binds the summary to
the external owner-only recovery bundle.

- The frozen 32-file baseline reconciled to a 46-file cutoff with a derived
  14-file delta and no missing or modified baseline file.
- All 679 legacy rows received one reviewed disposition: 380 retained core,
  255 archived Symphony, 43 regenerated epoch rows, and one target carry-forward.
- The fresh schema-13 core contains 55 stories, 149 traces, 11 backlog items,
  one reset/recomputed core tool, and zero applied legacy changesets.
- Source, fresh core, and target comparisons have zero missing, unexpected, or
  foreign-key-invalid identity rows. The only physical overlap is the explicit
  coordinated E11 receipt evidence allowlist.
- Target backlog `#10` became stable UID
  `blg_a7117d660af99f206c4662bdb3d2fbaf`; first apply changed one row and the
  content-identical second apply was a no-op. Items `#11`, `#12`, and `#14`
  remain explicitly archived/superseded.
- The checksummed journal switched the DB/log pair under a writer fence. Ten
  crash cases proved both forward and compensating recovery before the real
  transition was marked complete.
- Four product-neutral changesets cover 22 replay operations; 81 CLI tests,
  fresh-consumer changeset tracking, audit/proposal/matrix/backlog/tools, and
  no-live-root-log checks passed.
