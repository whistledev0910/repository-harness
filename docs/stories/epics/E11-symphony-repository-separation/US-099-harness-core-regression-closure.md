# US-099 Harness Core Regression Closure

## Status

planned

## Owner Repository

`repository-harness`

## Lane

normal with full release-grade validation.

## Product Contract

After cleanup, every major Harness CLI and template function remains available,
and the installer/release paths work without Symphony source or validation.

## Relevant Product Docs

- `README.md`
- `docs/HARNESS.md`
- `docs/TOOL_REGISTRY.md`
- `scripts/README.md`
- Decision `0009`

## Acceptance Criteria

- Cargo metadata reports only `harness-cli` and all CLI tests pass.
- A before/after command manifest shows no unintended removal of `init`,
  `migrate`, intake, story lifecycle/dependencies/hierarchy, decisions, backlog,
  tools, interventions, traces, audit/propose, queries, changeset apply, or DB
  rebuild behavior.
- Schema migrations 001 through the current version initialize and migrate both
  fresh and supported older databases.
- Generic synthetic replay and validator-contract suites pass with no product
  story IDs.
- Format, all-target clippy, locked tests, shell syntax, and diff checks pass.
- Bash fresh/merge/override/shim-refresh/dry-run installer smokes pass.
- PowerShell equivalent installer smokes pass on Windows CI.
- Bash and PowerShell checksum-verified CLI upgrade smokes replace an initial
  `US-092` protocol binary with the cleaned-core candidate while preserving
  consumer files and proving the template ref/binary tag tuple.
- A fresh install contains working local docs/links, schemas, ignored DB state,
  and the correct prebuilt CLI path for its platform.
- Release packaging builds/checksums every supported Harness CLI target and
  smokes the resulting binary.
- Post-merge automation bumps/releases the CLI only for real core inputs and
  renders bounded changelog entries.
- Core audit/propose/backlog/tools and automatic selection contain no
  active/runnable Symphony work or provider. Matrix may retain only completed
  E11 receipt proxies from the explicit historical allowlist; a status/ID
  assertion rejects every other Symphony-owned row.
- The separate Symphony release candidate passes its suite against both the
  exact initial `US-092` protocol release and this cleaned-core candidate. Each
  contract tuple is queried and compared directly; semver ordering is not used
  as compatibility evidence.

## Design Notes

- Compare behaviors, not historical test counts; new generic protocol/fixture
  tests may increase the original 73.
- Keep source and installed-payload checks separate.
- Run the target compatibility job against the exact candidate SHA/tag.
- Keep the initial protocol-tag run as a control, then upgrade the fixture and
  run the cleaned candidate with the same Symphony artifact.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Harness CLI tests including public orchestration protocol. |
| Integration | Schema migration, semantic replay, installer modes. |
| E2E | Clean installed Harness workflow plus external Symphony compatibility. |
| Platform | macOS/Linux/Windows CLI artifacts and PowerShell installer. |
| Release | Checksums, tag inputs, changelog cap, and binary smoke. |

```bash
cargo metadata --locked --no-deps --format-version 1
cargo fmt --check
cargo clippy -p harness-cli --all-targets -- -D warnings
cargo test -p harness-cli --locked
scripts/validate-changeset-rebuild.sh
scripts/test-validate-changeset-rebuild.sh
tests/core/assert-schema-replay-command-contract.sh
bash -n scripts/install-harness.sh
bash -n scripts/build-harness-cli-release.sh
scripts/build-harness-cli-release.sh
scripts/bin/harness-cli audit
scripts/bin/harness-cli query matrix
scripts/bin/harness-cli query backlog --open
scripts/bin/harness-cli query tools --summary
tests/installer/test-install-harness-modes.sh
# PowerShell installer modes run in the Windows CI job.
scripts/test-install-harness-cli-upgrade.sh
# Cross-repository candidate compatibility is recorded by the coordinated
# cutover workflow rather than executed from this core-only checkout.
git diff --check
```

## Harness Delta

Record any newly discovered missing core proof as a Harness backlog item; do not
reintroduce Symphony source to satisfy a test.

## Evidence

The core schema/command/replay gate migrates fresh databases and every prior
schema version from `001` through `012` to current `013`, checks integrity and
foreign-key closure, exercises the required public command manifest, validates
the protocol capability tuple, and runs product-neutral replay fixtures. The
remaining installer, packaging, platform, and cross-repository results are
attached by the complete story wrapper and coordinated cutover evidence; this
story remains a merge gate rather than remote cutover authorization.
