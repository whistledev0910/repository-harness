# Exec Plan

## Goal

Change canonical ownership with no interval in which either product lacks a
known-good source and with a verified rollback path.

## Scope

In scope:

- Target-first merge/release.
- Source cleanup merge/release.
- Released cross-repo smoke.
- Durable-state and repository audit.
- Safe reviewed runtime archival/pruning.
- Final readiness and rollback record.

Out of scope:

- New Symphony features.
- Harness policy redesign.
- Force-push or history deletion.

## Risk Classification

Risk flags:

- External systems and publication.
- Existing behavior.
- Data/history ownership.
- Cross-platform release.
- Multi-domain.

Hard gates:

- External release behavior.
- Data loss and rollback.
- Source-of-truth change.

## Work Phases

1. Reverify `US-096` and `US-099` artifacts.
2. Merge/publish target and verify checksums.
3. Merge/publish cleaned Harness and verify installer/CLI.
4. Run the released Symphony artifact against a clean fixture pinned to the
   initial `US-092` protocol tag.
5. Upgrade/install the exact cleaned-core Harness tag, verify its contract
   tuple, and rerun the same released cross-repository smoke.
6. Audit active docs, durable work, tools, proposals, and remote ownership.
7. Review/archive/prune old worktrees and runs safely.
8. Run the final cutover verifier against the checksum-bound readiness record.
9. Explicitly complete the story when every final assertion passes.

## Dependencies

- `US-096` target release candidate.
- `US-099` cleaned core regression closure.

## Stop Conditions

Pause if target artifacts are unavailable, checksums differ, cleaned Harness
fails install/release smoke, either named contract tuple is unsupported, any
cross-repo scenario regresses, active durable
state has wrong-owner work, or a dirty worktree lacks an explicit disposition.
Immediately before each remote push, merge, tag/release publication, or runtime
prune, obtain a fresh owner go/no-go naming the exact refs, tags, and checksums;
record it as intervention/evidence. Decision `0009` authorizes direction, not
unbounded future remote mutations.

## Rollback

- Before source merge: keep using repository-harness implementation and repair
  target.
- After source merge but before smoke: revert the cleanup PR or build from the
  pre-extraction tag; do not rewrite history.
- Protocol mismatch: fence work, roll the product named by the contract verdict
  back to the last recorded compatible tuple, and restore only its matching DB
  epoch.
- State loss or duplication: stop both writers/selectors, retain all current
  files for diagnosis, restore the exact paired DB/log epoch, compare stable UID
  sets and receipts, and do not prune runtime.
- Installer or release regression: stop advertising the bad artifact, revert
  the responsible installer/release/cleanup change through normal history, and
  verify a clean install before resuming.
- Wrong-owner suggestion: fence both selectors immediately, restore/correct the
  ownership/proxy epoch, and rerun matrix/work/board/receipt audits before any
  story becomes runnable.
- Platform-only failure: withhold the affected platform artifact and keep its
  previous known-good release; do not claim full cutover until the native smoke
  passes.

Any rollback that changes external release/ref state requires a fresh owner
go/no-go naming the exact action. After every repair, rerun Gates A-F and the
final cutover verifier before completion.
