# US-100 Evidence Contract

`scripts/verify-e11-us100.sh --readiness` is the pre-observation gate. It
requires the published Symphony release record, the cleaned Harness release,
both named protocol tuples and cross-repository smokes, the durable-state
audit, reviewed runtime disposition, and rollback proof. Passing readiness
does **not** permit story completion; `US-100` must still be `in_progress`.

Before the owner creates the Harness `develop` to `main` PR, run:

```bash
scripts/verify-e11-us100.sh --develop-candidate
```

This mode proves the published Symphony release, both pre-merge artifact
smokes, rollback evidence, and source ownership boundary. It deliberately does
not claim that the cleaned Harness release, runtime disposition, or observation
window exists. Those remain mandatory in `--readiness` and `--final`.

Canonical target ownership is checked from a fresh clone at the exact
published `main` commit, never from the long-lived local feature checkout:

```bash
fresh_target="$(mktemp -d)/symphony"
git clone git@github.com:hoangnb24/symphony.git "$fresh_target"
tests/cutover/assert-canonical-symphony-ownership.sh "$fresh_target" --json
```

The assertion requires `main`, tag `symphony-v0.1.0`, and commit
`2357bc4f333a12794f975a46dbc0df96599fe4c0` to agree. It also rejects a dirty
clone, forbidden hidden tool/runtime paths, tracked live changesets, and an
activated Harness database. This is safe pre-merge proof; final runtime-state
disposition remains a separate readiness requirement.

The successful fresh-clone result is recorded in
`canonical-target-ownership.json` with a checksum sidecar. Reproduce the JSON
from a new clone with the command above rather than treating a long-lived
local checkout as evidence.

`scripts/verify-e11-us100.sh --final` repeats every readiness check and also
requires `observation-window.json`. That record must prove all of the following:

- owner `hoangnb24` observed at least seven calendar days;
- one real development/use cycle completed before closure;
- all five named blocking-signal classes remained clear;
- no repair occurred inside the counted window (a repair requires a new record
  whose start is after the repair); and
- rollback artifacts remain retained.

The generated records use these schema identifiers:

- `e11-us100-symphony-release-v1` in `symphony-release.json`;
- `e11-us100-cutover-readiness-v1` in `cutover-readiness.json`; and
- `e11-us100-observation-window-v1` in `observation-window.json`.

Do not create a placeholder observation record merely to satisfy the file
name. Its timestamps and real-cycle evidence are completion evidence, and the
final verifier intentionally fails while the file is absent or the window is
not eligible.
