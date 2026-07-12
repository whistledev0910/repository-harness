# Validation

## Proof Strategy

Validate released artifacts and clean installs, then prove the absence of
wrong-owner active context in both repositories.

## Test Plan

| Layer | Cases |
| --- | --- |
| Unit | Release metadata/protocol tuple and checksum parsers. |
| Integration | Initial protocol-tag and cleaned-core Harness installs plus the same released Symphony artifact. |
| E2E | For each named tag: doctor -> work -> prepare -> deterministic execute -> Web -> sync. |
| Platform | Published native CLI artifacts and desktop smoke limitations. |
| Performance | Record startup/run smoke times for regression reference. |
| Logs/Audit | Remote refs, versions, active durable state, worktree disposition, observation window. |

## Fixtures

- Published/retrievable Symphony artifacts.
- Cleaned Harness release/install artifacts.
- Initial `US-092` Harness protocol release/install artifacts.
- Fresh temporary Git repository with one deterministic story.
- Source/target recovery tags, bundles, and DB backups.

## Commands

```bash
# Set these to downloaded native archives/binaries and the values from their
# published .sha256 sidecars. Run once per host-native tuple.
tests/cutover/released-cross-repo-smoke.sh \
  --symphony-archive "$SYMPHONY_ARCHIVE" \
  --symphony-sha256 "$SYMPHONY_SHA256" \
  --harness-cli "$HARNESS_PROTOCOL_V1_CLI" \
  --harness-cli-sha256 "$HARNESS_PROTOCOL_V1_SHA256" \
  --harness-label harness-cli-v0.1.14

tests/cutover/released-cross-repo-smoke.sh \
  --symphony-archive "$SYMPHONY_ARCHIVE" \
  --symphony-sha256 "$SYMPHONY_SHA256" \
  --harness-cli "$HARNESS_CLEAN_CORE_CLI" \
  --harness-cli-sha256 "$HARNESS_CLEAN_CORE_SHA256" \
  --harness-label "$HARNESS_CLEAN_CORE_TAG"

# Separately exercise the checksum-verified installer upgrade using the two
# native Harness binaries and the clean-core asset name/tag.
tests/installer/test-cli-upgrade-candidate.sh \
  "$HARNESS_PROTOCOL_V1_CLI" "$HARNESS_CLEAN_CORE_CLI" \
  "$HARNESS_CLEAN_CORE_ASSET_NAME" "$HARNESS_CLEAN_CORE_TAG"
scripts/bin/harness-cli audit
scripts/bin/harness-cli query matrix
scripts/bin/harness-cli query backlog --open
scripts/bin/harness-cli query tools --summary
scripts/bin/harness-cli propose
git worktree list --porcelain
test ! -e .agents && test ! -e .codex && test ! -e .impeccable
git bundle verify <source.bundle>
git diff --check
```

## Acceptance Evidence

Develop-candidate evidence is implemented: the published Symphony release and
checksums, initial-protocol and cleaned-develop artifact smokes, source durable
boundary, canonical target ownership assertion, and rollback rehearsal are
available under `evidence/` and `tests/cutover/`.

Cutover acceptance remains pending. The final report must additionally name
the cleaned Harness release SHA/tag and checksums, both released protocol
tuples and smoke outputs, completed runtime disposition, active-state audit,
and eligible observation-window end condition. Develop-candidate proof must
not be presented as evidence that those post-merge requirements have passed.

## Executable Story Gate

Use the readiness gate after both releases and both released smokes exist, but
before starting the observation window:

```bash
scripts/verify-e11-us100.sh --readiness
```

Cause and effect: readiness proves that cutover is safe enough to observe, but
it also asserts that `US-100` is still `in_progress`. It cannot complete the
story.

After at least seven calendar days **and** one complete real development/use
cycle, record the clear blocking-signal audit and run:

```bash
tests/cutover/test-us100-observation-gate.sh
scripts/verify-e11-us100.sh --final
```

The final mode repeats every readiness assertion, then validates the
observation record. An early close, missing use cycle, blocking signal, or
repair inside the counted window fails closed. A repair therefore creates a
new start time and restarts all seven days instead of reusing elapsed time.
