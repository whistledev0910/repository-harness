# US-100 Evidence Contract

`scripts/verify-e11-us100.sh --readiness` is the cutover evidence gate. It
requires the published Symphony release record, the cleaned Harness release,
both named protocol tuples and cross-repository smokes, the durable-state
audit, reviewed runtime disposition, and rollback proof. It deliberately keeps
`US-100` in progress until the separate final gate repeats those assertions.

Before the owner creates the Harness `develop` to `main` PR, run:

```bash
scripts/verify-e11-us100.sh --develop-candidate
```

This mode proves the current compatible Symphony release, preserves both
historical pre-merge `v0.1.0` artifact smokes, rollback evidence, and source
ownership boundary. It deliberately does not claim that the cleaned Harness
release tuple and released smoke evidence are assembled into a readiness
record. Those remain mandatory in `--readiness` and `--final`.

Canonical target ownership is checked from a fresh clone at the exact
published `main` commit, never from the long-lived local feature checkout:

```bash
fresh_target="$(mktemp -d)/symphony"
git clone git@github.com:hoangnb24/symphony.git "$fresh_target"
tests/cutover/assert-canonical-symphony-ownership.sh "$fresh_target" --json
```

The assertion requires `main`, tag `symphony-v0.1.1`, and commit
`2f0b257a0b145287c4b3b9e254fea5eca454c228` to agree. It also rejects a dirty
clone, forbidden hidden tool/runtime paths, tracked live changesets, and an
activated Harness database. This is safe pre-merge proof; final runtime-state
disposition remains a separate readiness requirement.

The successful fresh-clone result is recorded in
`canonical-target-ownership.json` with a checksum sidecar. Reproduce the JSON
from a new clone with the command above rather than treating a long-lived
local checkout as evidence.

`premerge-released-cross-repo-smokes.json` remains immutable causal evidence
for Symphony `v0.1.0` against Harness `v0.1.14` and the cleaned develop
candidate. It is not the readiness release. Readiness binds both named Harness
release smokes to the exact compatible `v0.1.1` archive recorded in
`symphony-release.json`; substituting another tag, commit, or archive fails.

`runtime-disposition.json` records the owner-approved cleanup of the 15 legacy
worktrees only after `audit-us100-runtime-disposition.sh --plan` proved that
every live patch matched its restore-rehearsed US-089 backup. Its post-cleanup
gate requires zero registered legacy worktrees, zero `.impeccable` files, and
zero active `.harness/changesets` files while preserving all 15 Git branches.

Readiness passed at `2026-07-12T15:54:50Z`. The checksummed `proof/` records
bind both release contracts and smokes, the clean install, ownership audit, and
reviewed runtime disposition. `scripts/verify-e11-us100.sh --final` repeats all
of those assertions before explicit completion is allowed.

The generated records use these schema identifiers:

- `e11-us100-symphony-release-v1` in `symphony-release.json`;
- `e11-us100-cutover-readiness-v1` in `cutover-readiness.json`.
