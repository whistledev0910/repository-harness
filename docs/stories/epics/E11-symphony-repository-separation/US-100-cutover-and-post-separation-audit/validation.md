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
| Logs/Audit | Remote refs, versions, active durable state, worktree disposition, and rollback proof. |

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

Develop-candidate evidence is implemented: historical Symphony `v0.1.0`
initial-protocol and cleaned-develop artifact smokes remain preserved, while
the current published compatible Symphony `v0.1.1` release and checksums,
source durable boundary, canonical target ownership assertion, and rollback rehearsal are
available under `evidence/` and `tests/cutover/`.

Cutover readiness passed at `2026-07-12T15:54:50Z`. The checksummed
record names the cleaned Harness release SHA/tag and checksums, both released
protocol tuples and smoke outputs, completed runtime disposition, active-state
audit, and the clean release install. Final acceptance repeats those assertions
before explicit story completion.
Both readiness smokes must use the exact `v0.1.1` archive; the historical
`v0.1.0` smoke cannot substitute for post-merge compatibility proof.

## Executable Story Gate

Use the readiness gate after both releases and both released smokes exist:

```bash
scripts/verify-e11-us100.sh --readiness
```

Cause and effect: readiness proves the cutover tuple while asserting that
`US-100` is still `in_progress`. Explicit completion remains a separate,
auditable lifecycle action.

Repeat the complete readiness assertions through the final gate:

```bash
scripts/verify-e11-us100.sh --final
```

The final mode repeats every readiness assertion and authorizes explicit story
completion only when the exact release, smoke, install, ownership, runtime,
rollback, and referenced-file checks all still pass.

Final acceptance passed on 2026-07-12. `harness-cli story complete US-100`
reran `scripts/verify-e11-us100.sh --final`, recorded a passing result, and
atomically marked the story implemented.
