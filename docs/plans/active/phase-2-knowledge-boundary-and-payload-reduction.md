# Phase 2 Epic: Knowledge Boundary And Payload Reduction

Date: 2026-07-21

## Status

Active — planning only. No installer default, payload, CLI, compatibility, or
historical path has changed.

## Outcome

Make the repository-centered Harness a physically small and unambiguous
installable core.

A default installation receives only the current repository workflow and its
Git-native knowledge and planning structure. The Rust CLI, SQLite runtime,
orchestration contract, and legacy lifecycle remain supported as one explicit
compatibility bundle. Upstream development material and historical evidence
remain available in this source repository without being installed into an
ordinary consumer.

Phase 2 makes the Phase 1 authority change structurally true. It does not claim
application legibility or improved agent behavior without a real application
and observed evidence.

## Context

- `AGENTS.md` and `docs/WORKFLOW.md` define the repository-centered default.
- `docs/decisions/0019-repository-centered-default-workflow.md` removed the
  SQLite lifecycle from the default task path while preserving compatibility.
- `docs/plans/completed/phase-1-workflow-decoupling.md` records the completed
  Phase 1 transition and its rollback boundary.
- `docs/README.md` already distinguishes current workflow material from
  compatibility references, but the installer payload still distributes both.
- `scripts/harness-install-files.txt`, the Bash and PowerShell installers, and
  their tests define the current consumer payload.
- `docs/contracts/harness-orchestration-v1.md` and the existing CLI release
  path are compatibility contracts that must not be broken by core reduction.
- OpenAI Harness Engineering remains the anchor: give agents a small map,
  preserve structured repository knowledge, and avoid a large competing
  instruction surface.

Decision `0019` currently names application legibility as the next investment.
Before implementation, Phase 2 must promote the knowledge-boundary and payload
direction into lasting decision documentation and explicitly defer
application-legibility claims until real application evidence exists.

## Scope

In scope:

- Classify installed and source-only artifacts as `core`, `compatibility`,
  `upstream-only`, or `historical`.
- Define a minimal default consumer payload.
- Separate core and compatibility installation profiles.
- Make the CLI and its required runtime one explicit, atomic compatibility
  add-on.
- Introduce a compatibility window before core-only installation becomes the
  default.
- Stop installing upstream `repository-harness` product and maintenance
  material as consumer truth.
- Keep current, compatibility, and historical knowledge separately indexed.
- Preserve existing installations, databases, binaries, release assets, and
  orchestration paths during the transition.
- Validate Bash and PowerShell behavior, merge/override/refresh safety, payload
  boundaries, links, and compatibility contracts.

Out of scope:

- Delete or rewrite an existing SQLite database or tracked core snapshot.
- Remove Rust CLI commands, migrations, changesets, or protocol-v1 behavior.
- Refactor the Rust CLI implementation.
- Build browser control, application runtime isolation, logs, metrics, or
  agent-behavior observation.
- Claim that the reduced payload improves application-development outcomes.
- Mass-move all story, review, migration, and evidence files in one change.
- Impose one architecture or fabricated validation command on consumers.
- Add a replacement task database, maturity ladder, trace, or scoring system.

## Product Boundaries

Every artifact must have one primary class and audience.

| Class | Primary audience | Default discovery | Default install |
| --- | --- | --- | --- |
| Core | Ordinary repository agents and consumers | Yes | Yes |
| Compatibility | Explicit CLI or orchestration users | Through a compatibility index | No |
| Upstream-only | `repository-harness` maintainers | In this source repository | No |
| Historical | Provenance and forensic review | Through a historical index | No |

The target default payload is intentionally small. Candidate core paths are:

```text
AGENTS.md
docs/WORKFLOW.md
docs/README.md
docs/product/README.md
docs/plans/README.md
docs/plans/active/README.md
docs/plans/completed/README.md
docs/decisions/README.md
docs/templates/exec-plan.md
```

The classification workstream must decide whether a shortened generic
`docs/HARNESS.md` belongs in core. It must not assume that the upstream root
`README.md` or current generic `docs/ARCHITECTURE.md` is consumer product truth.

The optional CLI bundle must be complete rather than binary-only. At minimum it
must account for:

```text
platform Harness CLI binary
bootstrap scripts
schema migrations
required compatibility documentation
protocol contract
database ignore rules
upgrade and checksum behavior
```

## Delivery Strategy

Use a compatibility-first migration:

```text
classify current artifacts
  -> define and validate a core-only preview
  -> retain the current full installation during a compatibility window
  -> make core-only the default
  -> require explicit selection for the CLI bundle
  -> relocate or delete obsolete material only in later work
```

Existing installations are never silently stripped. A core refresh leaves an
existing CLI and database untouched. CLI removal, if ever added, requires a
separate explicit and recoverable operation.

## Ordered Workstreams

### P2-01 — Reconcile Direction And Classify Artifacts

Depends on: none.

- Record the lasting Phase 2 direction and reconcile the application-legibility
  follow-up in decision `0019` before changing installer behavior.
- Classify every current installer-manifest path.
- Identify source files that are incorrectly presented as consumer truth.
- Identify required transitive members of the optional CLI bundle.
- Record unresolved classifications instead of guessing.

Exit evidence:

- Every installed path has one class, audience, install profile, and reason.
- No installer or filesystem behavior has changed.

### P2-02 — Define The Minimal Core Payload

Depends on: P2-01.

- Select the exact core files from the reviewed classification.
- Ensure the core map contains no mandatory CLI or SQLite lifecycle.
- Ensure the core does not replace a consumer's README or claim an unselected
  architecture as current truth.
- Define how an existing consumer's local product, architecture, and validation
  material is preserved.

Exit evidence:

- A proposed core manifest has no compatibility, upstream-only, or historical
  paths.
- Every core path is reachable from the compact documentation map.

### P2-03 — Add A Reversible Core-Only Preview

Depends on: P2-02.

- Add an explicit core-only/without-CLI installation mode while retaining the
  existing default during the compatibility window.
- Make dry-run reveal the selected profile and every planned write.
- Ensure core-only mode performs no CLI release download and adds no
  database-specific ignore rules.
- Keep Bash and PowerShell behavior equivalent.

Exit evidence:

- A fresh core-only fixture contains exactly the reviewed core payload.
- Existing full-install and upgrade behavior remains unchanged.

### P2-04 — Make The CLI An Atomic Optional Bundle

Depends on: P2-01 and P2-03.

- Add an explicit `--with-cli` / `-WithCli` selection for the compatibility
  bundle.
- Keep the stable binary path and immutable release/checksum rules.
- Require or imply CLI selection for explicit CLI upgrades.
- Fail without leaving a partial new binary, schema, bootstrap, or contract
  installation.
- Leave an already installed CLI untouched during an ordinary core refresh.

Exit evidence:

- Core plus CLI installs the complete reviewed compatibility bundle.
- Download or checksum failure leaves the core usable and an old CLI runnable.
- Protocol and historical upgrade tests remain green.

### P2-05 — Flip The Default After The Compatibility Window

Depends on: P2-03 and P2-04.

- Make core-only the default for fresh installations.
- Require explicit compatibility selection for the CLI bundle.
- Keep backed-up merge, override, refresh, and CLI-upgrade behavior explicit.
- Document the change without presenting compatibility commands as default
  workflow steps.

Exit evidence:

- The default installer performs no CLI download.
- Explicit CLI consumers retain the stable command path and protocol.
- Existing installations are not destructively stripped.

### P2-06 — Separate Current, Compatibility, And Historical Discovery

Depends on: P2-01 and P2-02. May proceed alongside P2-03 and P2-04 after the
classification is stable.

- Keep one small current documentation map.
- Add or refine explicit compatibility and historical indexes.
- Separate current, compatibility, and historical decisions in the decision
  index without renumbering history.
- Stop default documentation from deep-linking into historical lifecycle
  instructions.
- Use banners or thin redirect documents during path deprecation; do not
  mass-move the historical tree.

Exit evidence:

- Current workflow retrieval does not require compatibility or historical
  material.
- Compatibility and provenance remain deliberately discoverable.
- Link and documentation-contract tests pass.

### P2-07 — Close The Epic With Repository Evidence

Depends on: P2-04, P2-05, and P2-06.

- Run focused payload, installer, documentation, and compatibility checks.
- Run the full pre-merge repository contract in a fresh checkout or worktree.
- Review the final default and optional payloads as concrete file lists.
- Record limitations and deferred application-legibility work.
- Move this plan to `docs/plans/completed/` only after the default has flipped
  and all compatibility evidence passes.

## Dependency Map

```text
P2-01 classify and decide
  -> P2-02 define core
      -> P2-03 preview core-only
          -> P2-04 optional CLI bundle
              -> P2-05 flip default
  -> P2-06 separate discovery

P2-05 + P2-06 -> P2-07 close and retain evidence
```

## Risks And Recovery

### External consumer breakage

Risk: an external runner may assume that a normal install always provides
`scripts/bin/harness-cli`.

Mitigation: retain the existing default during a compatibility window, provide
explicit CLI selection, preserve the stable path, and keep protocol/upgrade
tests.

Recovery: restore the prior installer default without reconstructing deleted
data or binaries. Do not restore mandatory CLI use to the repository workflow.

### Partial compatibility installation

Risk: the binary is installed without schemas, bootstrap, or its required
contract.

Mitigation: treat CLI compatibility as one reviewed atomic bundle and test
failure at download and checksum boundaries.

Recovery: leave the previous CLI and complete bundle untouched; remove only a
staged temporary candidate.

### Source and consumer truth remain conflated

Risk: upstream README, architecture, release, or maintenance material continues
to appear authoritative in consumers.

Mitigation: classify audience before profile membership and test consumer
fixtures containing their own README and architecture.

Recovery: remove the upstream-only path from the core manifest; do not overwrite
the consumer file.

### Historical evidence becomes unreachable

Risk: reducing default discovery accidentally removes provenance required for
maintenance or compatibility review.

Mitigation: index and demote before relocating; preserve Git history and old
paths during the compatibility window.

Recovery: restore an index or redirect. Do not copy the entire historical tree
back into the core payload.

### Profile complexity becomes a new permanent product

Risk: transitional flags and manifests create another large configuration
surface.

Mitigation: support only core and core-plus-CLI profiles, document their
sunset/default behavior, and reject combinatorial feature selection.

Recovery: collapse aliases after the compatibility window while keeping one
explicit CLI opt-in.

## Acceptance Criteria

- The default fresh install contains only reviewed core paths.
- The default fresh install downloads no CLI binary.
- The default fresh install contains no schema, bootstrap, SQLite lifecycle,
  orchestration, legacy story, scoring, audit, proposal, or historical files.
- The default fresh install does not replace an existing consumer README,
  architecture document, product contract, or validation configuration.
- The optional CLI selection installs one complete, checksum-verified
  compatibility bundle.
- Core dry-run makes no CLI network request and reports no database-specific
  writes.
- Core refresh leaves an existing CLI and database untouched.
- Explicit CLI upgrade retains immutable ref, checksum, backup, and atomic
  replacement behavior.
- Bash and PowerShell install profiles have equivalent contracts.
- Current, compatibility, upstream-only, and historical material have separate
  indexes and no artifact has conflicting default authority.
- Existing protocol-v1, fresh bootstrap, historical upgrade, and release
  compatibility proof continues to pass.
- Phase 2 records no claim about application legibility or agent behavior.

## Validation

Focused proof to define during implementation:

- Installer manifest classification and profile membership assertions.
- Fresh core-only Bash and PowerShell fixtures.
- Consumer README/architecture preservation fixtures.
- Core dry-run no-download assertions.
- Explicit CLI-bundle completeness and failed-download rollback fixtures.
- Existing CLI refresh and immutable upgrade fixtures.
- Documentation index, link, and stale-default-guidance checks.
- Existing orchestration protocol and source-state compatibility checks.

Repository-required proof before completion:

```text
tests/installer/assert-agent-authority-contract.sh
tests/installer/assert-install-manifest-links.sh
tests/installer/test-install-harness-modes.sh
tests/installer/test-install-harness-modes.ps1
tests/docs/test-doc-contracts.sh
tests/protocol/smoke-native-artifact.sh
tests/protocol/smoke-native-artifact.ps1
tests/installer/test-cli-upgrade-candidate.sh
scripts/validate-premerge.sh
git diff --check
```

The final command set may change as the installer profiles are designed. Any
replacement must prove the same behaviors rather than merely rename a check.

## Progress

- [x] Agree that repository-only Phase 2 should not claim unobserved application
      legibility or agent behavior.
- [x] Define the epic outcome, boundaries, migration order, risks, and initial
      acceptance criteria.
- [ ] P2-01: reconcile lasting direction and classify artifacts.
- [ ] P2-02: define the minimal core payload.
- [ ] P2-03: add the reversible core-only preview.
- [ ] P2-04: make the CLI an atomic optional bundle.
- [ ] P2-05: make core-only the default after the compatibility window.
- [ ] P2-06: separate current, compatibility, and historical discovery.
- [ ] P2-07: validate, record the result, and move this plan to completed.

## Decisions

- 2026-07-21: Phase 2 is repository-only knowledge-boundary and payload
  reduction. Application legibility is deferred until a real application and
  observable evidence exist.
- 2026-07-21: The CLI becomes optional through explicit atomic packaging, not
  deletion or silent removal from existing installations.
- 2026-07-21: Core and core-plus-CLI are the only intended install profiles;
  Phase 2 will not create arbitrary feature combinations.
- 2026-07-21: Classification and a reversible preview precede changing the
  installer default.
- 2026-07-21: Historical evidence is indexed and demoted before any relocation.

## Result

Pending. This epic currently records the agreed Phase 2 direction and execution
boundary only. Implementation has not started.
