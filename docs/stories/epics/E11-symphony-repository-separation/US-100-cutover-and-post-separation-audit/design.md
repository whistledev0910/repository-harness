# Design

## Domain Model

Cutover records one compatible tuple:

```text
Symphony release SHA/tag/artifact checksum
initial protocol-v1 Harness SHA/tag/artifact checksum
cleaned-core Harness SHA/tag/artifact checksum
Harness protocol version and schema range
cross-repo smoke evidence for both named Harness tags
```

Canonical ownership changes only when that tuple passes.

## Application Flow

```text
merge target
  -> publish/verify Symphony candidate
  -> merge cleaned Harness
  -> wait for and verify the cleaned Harness CLI release tag/artifacts
  -> smoke released Symphony against the initial protocol-v1 tag
  -> upgrade a clean fixture to the cleaned tag with checksum verification
  -> smoke the same Symphony artifact against the cleaned tag
  -> audit durable state/docs/remotes
  -> prune reviewed local runtime
  -> verify the final checksum-bound cutover tuple
  -> explicitly complete US-100
```

## Interface Contract

Release notes state both tested tags, their discovered protocol tuples, and the
upgrade order. An incompatible combination fails in `doctor` before work
starts. Compatibility is based on contract fields/capabilities, never on a
guess that a numerically newer patch is equivalent.

## Data Model

Core and Symphony active DBs remain separate local files. Backup restoration is
epoch-specific; databases and changeset sets are never mixed across epochs.

## UI / Platform Impact

Web/desktop release evidence names any unsigned/unnotarized limitation. A
packaged desktop opens a normal Harness project without expecting source paths.

## Observability

Post-cutover evidence captures versions, checksums, command output, audit and
proposal results, remote refs, runtime disposition, and rollback proof.

## Alternatives Considered

1. Merge source cleanup first. Rejected because a failed target publication
   would leave no canonical Symphony implementation.
2. Keep both implementations indefinitely. Rejected because agents would again
   receive competing product truth.
3. Delete local runtime immediately after smoke. Rejected because dirty
   worktrees and rollback evidence require reviewed disposition.
