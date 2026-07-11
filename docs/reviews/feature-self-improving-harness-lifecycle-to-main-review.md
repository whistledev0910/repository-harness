# Branch Review: `feature/self-improving-harness-lifecycle` Against `main`

> **Review status:** All recorded findings are resolved. US-085 closes the
> causality-audit findings with shared semantic integrity rules and isolated
> validator proof.

## Review Boundary

- Base: `main` at `14e6f102a4a645562d046f7c693c61401261cac6`
- Reviewed head: `9c9e8c841315be774950dde1393039b066929c71` plus the uncommitted US-082 through US-085 closure changes
- Initial size: 53 changed files, approximately 8,233 insertions and 221 deletions
- Primary risk area: lifecycle identity, semantic changeset replay, story/backlog
  closure, recurrence classification, and legacy reconciliation

## Review Result

- Branch findings: **27**
- Merge-blocking P1 findings: **14**
- P2 correctness/documentation findings: **13**
- Reproducible baseline defects already present on `main`: **2**
- Resolution: **All 27 branch findings and both baseline observations are closed.**

## Resolution Matrix

| Item | Resolution | Proof |
| --- | --- | --- |
| F-001 | Semantic completion/backlog operations replay exact completion and closure time. | `review_finding_live_rebuild_recurrence_parity`; exact completion replay test |
| F-002 | The duplicate glossary definition was removed and the remaining definition uses explicit accept/reject decisions. | `! rg -- '--commit' docs/GLOSSARY.md` |
| F-003 | RFC3339 is parsed with `chrono`, including negative offsets. | `review_finding_rfc3339_unicode_and_exact_rejection_reason` |
| F-004 | Decisions reject synthetic audit evidence until explicit episode recording. | `review_finding_audit_decisions_require_stable_evidence_and_replay_replacement` |
| F-005 | New traces/links carry nanosecond order and legacy fallback is strict. | `review_finding_resolver_link_order_is_precise_and_replayable` |
| F-006 | Link timestamps and nanosecond order replay exactly. | `review_finding_resolver_link_order_is_precise_and_replayable` |
| B-001 | Unicode title truncation uses character boundaries. | Unicode truncation case in `review_finding_rfc3339_unicode_and_exact_rejection_reason` |
| B-002 | Evidence normalization retains Unicode alphanumeric characters. | Non-Latin separation case in `review_finding_rfc3339_unicode_and_exact_rejection_reason` |
| F-009 | Timestamped US-073..US-081 proof changeset restores US-074 and rebuild validation checks proof. | `run_1783741400_e09_proof_parity`; rebuild restored 56 stories |
| F-010 | Verification operations carry and replay `verified_at`. | exact completion replay test; rebuild proof timestamp assertions |
| F-011 | Lightweight copied databases enter `in_progress`. | `review_finding_lightweight_copy_enters_in_progress` |
| F-012 | Fingerprint replacement emits clear then open operations. | audit replacement live/replay equality test |
| F-013 | Rejection reasons use a structured column and exact equality. | exact/prefix rejection test |
| F-014 | Completion selects the newest resolver boundary and uses its precision mode, so one older legacy link cannot disable a newer precise boundary. | `proof_audit_mixed_resolver_semantic_history_matches_after_replay` |
| F-015 | Migration 012 extracts the first exact legacy rejection-reason line into structured state. | `post_review_migration_backfills_exact_legacy_rejection_reason` |
| F-016 | Rebuild validation builds the current workspace CLI by default, honors only an explicit override, and prints executable/source identity. | source-matched rebuild restored 57 stories |
| F-017 | Repository validation checks passing timestamped proof without freezing mutable timestamps; exact replay remains a focused Rust invariant. | 57-story rebuild plus exact timestamp replay tests |
| F-018 | Mixed v1/v2 link and trace operations are applied to two fresh repositories and produce identical rejection, proof UID, and closure results. | `proof_audit_mixed_resolver_semantic_history_matches_after_replay` |
| F-019 | Acceptance text matches the source-build/default and explicit-override contract; shell tests cover both plus missing and unrelated executables. | `scripts/test-validate-changeset-rebuild.sh` |
| F-020 | A temporary later `story.verify` changeset rebuilds successfully and the newer timestamp wins. | later-verification shell fixture |
| F-021 | JSON list input is normalized; clean detailed trace 232 has six actions and zero errors while historical traces remain append-only. | `proof_audit_json_list_input_is_normalized_instead_of_split_into_fragments`; trace 232 query |
| F-022 | v2 replay requires a canonical timestamp and repository validation applies the invariant to US-073 through US-084. | garbage/missing/valid timestamp shell fixtures |
| F-023 | Binary selection is an injectable function tested against exact debug/installed candidate paths with the installed candidate newer. | isolated selection-root shell fixture |
| F-024 | Operation rejection and SQL proof validation have separate causal fixtures. | direct rebuild rejection plus `proof_is_valid` database mutations |
| F-025 | JSON-like CLI input is typed: valid string arrays normalize while mixed, object, and malformed shapes return errors. | `semantic_integrity_json_like_lists_are_typed_and_csv_remains_supported` |
| F-026 | Canonical timestamp parsing round-trips formatted output and rejects unpadded text. | semantic-integrity canonical helper cases |
| F-027 | Version 2 story completion requires canonical `completed_at`; v1 retains legacy fallback. | operation-family table test and 59-story rebuild |
| F-028 | Version 2 backlog completion uses the same required canonical time contract. | operation-family table test and 59-story rebuild |
| F-029 | Required and optional timestamps across lifecycle operation families use shared helpers, including nested evidence. | `semantic_integrity_rejects_noncanonical_timestamps_across_operation_families` |

## Findings

### F-001 — P1 — Rebuild changes closure time and can suppress a real regression

**Location**

- `crates/harness-cli/src/infrastructure.rs:1574-1582`
- `crates/harness-cli/src/infrastructure.rs:4202-4207`
- `crates/harness-cli/src/infrastructure.rs:4442-4454`

**What happens**

The live `story complete` path calculates `completed_at` and includes it in the
`story.complete` operation and inside `resolution_evidence`. However, the
`backlog.complete` operation does not contain a closure timestamp. During
changeset replay, both `story.complete` and `backlog.complete` ignore the
recorded `completed_at` and write `datetime('now')` instead.

Concrete cause and effect:

1. A backlog is completed at `2026-07-10 10:00:00`.
2. New matching evidence is recorded at `2026-07-10 11:00:00`.
3. On the live database, recurrence classification correctly sees
   `11:00 >= 10:00` and exposes a regression.
4. The database is rebuilt on `2026-07-11 09:00:00`.
5. Replay changes the backlog's `closed_at` to `2026-07-11 09:00:00`.
6. Recurrence classification now evaluates the same evidence as
   `2026-07-10 11:00 < 2026-07-11 09:00` and removes it.
7. The rebuilt database suppresses a regression that the source database
   exposed, so replay no longer preserves lifecycle meaning.

This is merge-blocking because rebuild is the repository's durable
source-of-truth path and recurrence depends directly on the lost timestamp.

**Required correction**

- Put the authoritative completion/closure timestamps in the semantic
  operations.
- Replay those exact values into `story.last_verified_at`,
  `backlog.implemented_at`, and `backlog.closed_at` instead of using rebuild
  time.
- Add a parity test with evidence created after closure, rebuild at a later
  time, and assert that both databases classify the proposal as a regression.

### F-002 — P2 — The living glossary directs users to a command that now always fails

**Location**

- `docs/GLOSSARY.md:76-80`
- `docs/GLOSSARY.md:140-144`
- `crates/harness-cli/src/interface.rs:465-484`
- `crates/harness-cli/src/interface.rs:964-968`

**What happens**

This branch intentionally replaces bulk `propose --commit` with explicit
`--accept` and `--reject` decisions. The CLI exits with status 2 whenever
`--commit` is supplied, and the updated Harness/protocol documents describe
that behavior. However, both `Improvement Proposal` entries in the living
glossary still say proposals are committed with `--commit`.

Concrete cause and effect:

1. A user looks up “Improvement Proposal” in the repository glossary.
2. The glossary tells them to run `harness-cli propose --commit`.
3. The CLI unconditionally prints a replacement-command error and exits 2.
4. The documented path can never perform the operation the glossary promises.

Historical story and review files may retain old command evidence, but the
current glossary is an active reference and must match the new public command
contract.

**Required correction**

- Update both duplicate glossary definitions to describe read-only proposal
  generation plus one-key `--accept`/`--reject` decisions.
- Prefer removing the duplicate glossary section so this contract has one
  maintained definition.
- Add a documentation consistency check for retired CLI flags in living docs,
  excluding explicitly historical records.

### F-003 — P2 — A valid RFC3339 due time with a negative offset is rejected

**Location**

- `crates/harness-cli/src/infrastructure.rs:3589-3600`
- `docs/IMPROVEMENT_PROTOCOL.md:82-84`

**What happens**

The public contract accepts an RFC3339 value for `--outcome-due`, but the parser
does not parse RFC3339. It accepts a value only when it ends in `Z` or contains
`+`. A valid negative UTC offset therefore fails before SQLite evaluates the
time.

Concrete example:

```text
2099-01-01T12:00:00-05:00
```

This is a valid future RFC3339 timestamp. It contains `T`, but it neither ends
with `Z` nor contains `+`, so Harness returns “outcome due time must be
RFC3339.” Users west of UTC cannot submit their local offset as documented.

**Runtime proof**

Against an isolated database with a real generated proposal key, the reviewed
CLI command using `--outcome-due 2099-01-01T12:00:00-05:00` exited 1 with:

```text
error: proposal decision: outcome due time must be RFC3339
```

**Required correction**

- Parse the value with an RFC3339-aware datetime parser instead of checking
  delimiter characters.
- Preserve the later-than-acceptance validation after parsing.
- Add acceptance tests for `Z`, positive offsets, and negative offsets, plus
  rejection tests for malformed dates and trailing garbage.

### F-004 — P1 — Audit proposals can be decided without stable evidence and later become false recurrences

**Location**

- `docs/stories/epics/E09-self-improving-harness-lifecycle/US-075-selective-proposal-decision.md:58-62`
- `crates/harness-cli/src/infrastructure.rs:307-350`
- `crates/harness-cli/src/infrastructure.rs:4092-4124`
- `crates/harness-cli/src/infrastructure.rs:4187-4208`

**What happens**

US-075 requires acceptance and rejection to refuse a current audit proposal
that has no active recorded audit episode, directing the operator to
`audit --record-evidence`. The decision path checks stale keys, schedules, and
legacy backlog title collisions, but never checks the proposal's evidence kind.
Consequently it accepts the synthetic `legacy_snapshot` evidence generated for
an unrecorded audit finding.

Concrete cause and effect:

1. `audit` reports an unverified story, but no one has run
   `audit --record-evidence` yet.
2. `propose` represents that finding with source kind `legacy_snapshot`, UID
   equal to the finding key, and timestamp `1970-01-01 00:00:00`.
3. Contrary to the story contract, `propose --accept ...` or `--reject ...`
   succeeds and records that synthetic evidence as covered.
4. The occurrence later closes.
5. The operator follows the daily protocol and runs `audit --record-evidence`
   while the underlying finding is unchanged.
6. Harness creates a real audit episode with a new `aud_...` UID and a current
   timestamp.
7. Recurrence classification compares evidence by `(source_kind, uid)`, so the
   real episode is not considered covered; because its timestamp is after
   closure, the unchanged finding is reported as a regression or
   reconsideration.

The missing gate both violates an explicit acceptance criterion and allows
Harness to generate new work from an evidence-identity migration rather than a
new problem.

**Required correction**

- Before either decision, reject proposals containing synthetic audit
  `legacy_snapshot` evidence with the specified
  `run harness-cli audit --record-evidence` guidance.
- Keep preview read-only; do not silently create the audit episode during a
  proposal decision.
- Add acceptance and rejection tests for an unrecorded audit finding, followed
  by a recorded-episode happy path.
- Add a regression test proving that recording the same unchanged finding
  cannot create a recurrence after closure.

### F-005 — P1 — A pre-link trace can satisfy the post-link completion gate within the same second

**Location**

- `crates/harness-cli/src/infrastructure.rs:4845-4863`
- `scripts/schema/010-story-backlog-links.sql:2-10`
- `docs/stories/epics/E09-self-improving-harness-lifecycle/US-077-explicit-story-completion/overview.md:61-66`

**What happens**

Resolver completion is supposed to require an implementation trace recorded at
or after the newest resolver link. The query compares `trace.created_at` with
`MAX(story_backlog_link.linked_at)`, but both values use SQLite
`datetime('now')`, which has only one-second precision.

Concrete cause and effect:

1. At real time `10:00:00.100`, a completed trace is recorded for a story.
2. At real time `10:00:00.800`, a new `resolves` link is added.
3. Both durable timestamps are stored as `10:00:00`.
4. Completion evaluates `trace.created_at >= linked_at` as true.
5. The older trace is accepted as proof for a resolver relationship that did
   not exist when the trace was produced.

This bypasses the explicit “missing/early trace refuses completion before
verification” acceptance criterion. The existing test uses timestamps separated
by whole days and therefore does not cover equal stored timestamps with reversed
real ordering.

**Required correction**

- Use a durable ordering boundary that cannot collapse distinct operations,
  such as a captured trace baseline/sequence at link time or a sufficiently
  precise replayed timestamp plus a deterministic tie-breaker.
- Preserve that boundary in the semantic link operation and rebuild.
- Add a test that writes the qualifying-looking trace first and the resolver
  link second with identical stored timestamps, then asserts completion is
  refused.

### F-006 — P1 — Rebuild moves resolver-link time forward and invalidates legitimate implementation traces

**Location**

- `crates/harness-cli/src/infrastructure.rs:1385-1389`
- `crates/harness-cli/src/infrastructure.rs:4408-4421`
- `crates/harness-cli/src/infrastructure.rs:4858-4863`

**What happens**

The live link mutation writes `linked_at=datetime('now')`, but its semantic
`story.backlog.link` operation contains only `backlog_uid` and `relationship`.
Replay also writes `linked_at=datetime('now')`, which means rebuild time rather
than the original link time becomes the proof boundary.

Concrete cause and effect:

1. A resolver link is created on July 10 at 10:00.
2. Its valid implementation trace is recorded on July 10 at 11:00.
3. The database is rebuilt on July 11 at 09:00.
4. Replay stores the resolver link as July 11 at 09:00 while preserving the
   trace's July 10 timestamp.
5. `story complete` requires `trace.created_at >= MAX(linked_at)` and now
   rejects the previously valid trace as early.
6. The operator must record artificial new implementation evidence after every
   rebuild, or cannot complete the story from the reconstructed source of truth.

This contradicts the replayable-relationship and exact proof-boundary contract.

**Required correction**

- Capture the live `linked_at` value and include it in every link semantic
  operation.
- Replay the supplied value exactly; do not derive it from wall-clock rebuild
  time.
- Add live-versus-rebuilt parity coverage for a resolver link followed by a
  qualifying trace before story completion.

## Baseline Observations Excluded From Branch Findings

The following defects were discovered during runtime review, but provenance
checking confirms their relevant logic already exists on `main`. They remain in
this ledger because they are real and reproducible, but they are not counted as
findings introduced by this branch.

### B-001 — Existing on `main` — Long Unicode evidence can panic `propose`

**Location**

- `crates/harness-cli/src/infrastructure.rs:4246-4256`
- Callers at `crates/harness-cli/src/infrastructure.rs:2952` and `:2975`

**What happens**

`short_title` measures a Rust string in bytes with `words.len()`, then truncates
it using the byte range `&words[..69]`. Byte offset 69 is not guaranteed to be a
UTF-8 character boundary, so valid friction or intervention text can panic the
process.

Concrete example shape:

```text
<68 ASCII characters><one emoji><four more ASCII characters>
```

The joined string exceeds 72 bytes, the emoji begins at byte 68, and slicing at
byte 69 cuts through its encoding. Rust panics instead of returning a proposal.
Because trace friction and intervention descriptions are user-controlled text,
this is reachable through normal CLI data rather than corrupt database input.

**Runtime proof**

After rebuilding `target/debug/harness-cli` from the reviewed head, two normal
`trace` commands with the example-shaped friction followed by `propose` exited
101 with:

```text
panicked at crates/harness-cli/src/infrastructure.rs:4253:32:
byte index 69 is not a char boundary; it is inside '🙂' (bytes 68..72)
```

**Required correction**

- Truncate by Unicode scalar/grapheme count or find the last valid character
  boundary at or before the desired byte limit.
- Define whether the 72-character limit means Unicode characters, graphemes, or
  display width and apply it consistently.
- Add non-ASCII tests with the truncation point inside multi-byte emoji and
  accented characters.

### B-002 — Existing on `main` — Unrelated non-ASCII evidence is grouped as one repeated problem

**Location**

- `crates/harness-cli/src/domain.rs:1268-1287`
- `crates/harness-cli/src/infrastructure.rs:4059-4088`

**What happens**

Repeated friction and intervention grouping uses `normalize_token`, which keeps
only `is_ascii_alphanumeric()` characters. Distinct text written entirely in a
non-Latin script normalizes to the same empty key.

Concrete cause and effect:

1. One trace records Japanese friction meaning “the database is slow.”
2. Another trace records unrelated Japanese friction meaning “authentication
   failed.”
3. Both strings normalize to `""`.
4. `repeated_values` places them in one group with count 2.
5. `propose` reports the first problem as repeated twice and can assign medium
   confidence even though the two evidence items describe different failures.

Mixed-language strings can also lose meaningful accented/non-ASCII letters and
collide after separators are collapsed. The result is false proposal evidence,
not merely a display defect.

**Required correction**

- Use Unicode-aware alphanumeric classification and normalization for
  human-authored evidence grouping.
- If meaningful canonicalization is not possible, keep the normalized Unicode
  text rather than collapsing it to an empty key.
- Add tests proving that unrelated Japanese (or another non-Latin script)
  strings remain separate while case/whitespace variants of the same Unicode
  text still group together.

## Findings (Continued)

### F-009 — P1 — The committed rebuild loses US-074 verification and creates audit drift

**Location**

- `.harness/changesets/run_1783680342594999000_45616_0.changeset.jsonl:2-3`
- `scripts/validate-changeset-rebuild.sh:18-67`

**What happens**

The live database records US-074 as implemented with a passing verification at
`2026-07-10 11:03:17`. Its committed completion changeset contains a
`story.update` and a trace, but no `story.verify` or `story.complete` operation.
The rebuild validator checks only that each expected story row exists (plus a
small status/dependency subset), so it reports success while dropping the proof.

Direct parity result at reviewed head:

```text
live US-074:    status=implemented, last_verified_result=pass
rebuilt US-074: status=implemented, last_verified_result=NULL

live audit:     unverified stories=0, entropy=0/100
rebuilt audit:  unverified stories=1 (US-074), entropy=5/100
```

The committed source of truth therefore reconstructs a different audit state
from the live database, despite `scripts/validate-changeset-rebuild.sh` printing
success.

**Required correction**

- Add the missing replayable US-074 verification evidence through the normal
  semantic changeset workflow.
- Strengthen rebuild validation to compare required status, proof flags, and
  `last_verified_result`, not merely row presence.
- Assert that the rebuilt audit has the expected entropy and no missing E09
  proof before declaring rebuild success.

### F-010 — P2 — Verification replay replaces proof time with rebuild time

**Location**

- `crates/harness-cli/src/infrastructure.rs:1447-1463`
- `crates/harness-cli/src/infrastructure.rs:4433-4445`

**What happens**

Live `story.verify` operations record only `result`; they omit the generated
`last_verified_at`. Replay consequently assigns `datetime('now')`. The same
problem affects `story.complete`, which carries `completed_at` but does not use
it for `last_verified_at` during replay.

In a fresh rebuild during this review, US-073 and US-075 through US-081 all
received the identical rebuild timestamp `2026-07-11 03:03:17`, replacing their
distinct July 10 proof times. US-074 lost proof entirely as described in F-009.

This makes the durable verification history depend on when a database happens
to be reconstructed and prevents reliable live-versus-rebuilt parity.

**Required correction**

- Include the authoritative verification timestamp in `story.verify` semantic
  operations.
- Use `story.complete.payload.completed_at` as the replayed proof timestamp for
  completion, or carry a separate explicit verification timestamp if they can
  differ.
- Add equality assertions for proof result and proof timestamp in rebuild tests.

### F-011 — P1 — Lightweight Symphony runs leave the copied story planned, so `story complete` cannot succeed

**Location**

- `crates/harness-symphony/src/run.rs:126-141`
- `crates/harness-symphony/src/run.rs:166-220`
- `crates/harness-symphony/src/run.rs:319-325`
- `crates/harness-cli/src/infrastructure.rs:1510-1514`

**What happens**

`prepare_run` copies `harness.db` into an isolated worktree and calls
`mark_story_in_progress`. `prepare_here_run`, the lightweight path allowed for
tiny stories, also copies the database but never calls that function. Both paths
generate the same instruction requiring resolver stories to record a trace and
then run `story complete`.

Concrete cause and effect:

1. A tiny planned resolver story is started through Symphony's `--here` path.
2. Its copied database still says `status='planned'`.
3. The agent implements the work and records the required completed trace.
4. It follows `RUN_CONTRACT.json` and invokes `story complete`.
5. Completion refuses the story because only `in_progress` or `changed` is
   eligible.
6. The lightweight run cannot produce the required completion transition unless
   the agent performs an undocumented manual status mutation.

The US-077 acceptance criterion requires Symphony to establish copied
`in_progress` state before implementation; it does not exempt lightweight runs.
The existing lightweight preparation test verifies the copied file and run
record but not the copied story status.

**Required correction**

- Call `mark_story_in_progress` for the lightweight copied database before
  writing the contract/starting the agent.
- Add a `prepare_here_run` test asserting a planned copied story becomes
  `in_progress` while a pre-existing terminal state is never rewritten.
- Add an end-to-end lightweight resolver fixture that records its trace and
  successfully executes `story complete` from the copied database.

### F-012 — P1 — Audit fingerprint changes omit the clear operation and make changeset replay fail

**Location**

- `crates/harness-cli/src/infrastructure.rs:2905-2939`
- `scripts/schema/009-improvement-identity.sql:37-43`

**What happens**

`audit_record_evidence` handles two ways an active episode ends:

- If the finding key disappears, it clears the row and appends an
  `audit.evidence.clear` operation.
- If the same finding key remains but its fingerprint changes, it clears the
  old row in SQLite but appends no clear operation, then appends only the new
  `audit.evidence.open` operation.

Concrete cause and effect:

1. `audit --record-evidence` opens an episode for an unverified story.
2. The story remains unverified, but its title changes, producing a new
   fingerprint for the same finding key.
3. A later `audit --record-evidence` clears the old live episode and opens the
   replacement successfully.
4. Its changeset contains the replacement open but not the old clear.
5. Rebuild replays the original open, leaving it active.
6. Rebuild then replays the replacement open.
7. The `audit_one_active_finding` partial unique index rejects two active rows
   for the same finding key, aborting the changeset and the rebuild.

**Required correction**

- In the fingerprint-change branch, capture the old row's `cleared_at` and emit
  the same `audit.evidence.clear` semantic operation used by the disappeared-key
  branch before emitting the replacement open.
- Add replay coverage for unchanged findings, disappeared findings, and
  same-key/new-fingerprint findings.
- Assert both live/rebuilt episode history and successful full database rebuild.

### F-013 — P2 — Rejection idempotency treats a prefix as the same reason

**Location**

- `crates/harness-cli/src/infrastructure.rs:441-459`

**What happens**

When an occurrence is already rejected, idempotency checks whether its notes
`contains("rejection_reason: <new reason>")`. This is a substring test rather
than exact structured equality.

Concrete cause and effect:

1. A proposal is rejected with reason `not useful yet`.
2. A later caller retries the same key with the different reason `not useful`.
3. The stored text `rejection_reason: not useful yet` contains
   `rejection_reason: not useful`.
4. Harness reports the occurrence as “unchanged” instead of rejecting the
   conflicting decision.

The row is not rewritten, but the command falsely confirms that a materially
different human decision matches durable state.

**Runtime proof**

In an isolated database, rejecting a generated key with `not useful yet` and
then rejecting the same key with `not useful` returned:

```text
Proposal ... unchanged: rejected backlog #1.
```

The second reason was never equal to the stored first reason.

**Required correction**

- Store rejection reason in a dedicated field or parse the exact reason line
  and compare equality.
- Add tests for exact retry, strict-prefix retry, strict-superset retry, and
  newline-containing reasons.

## Validation Evidence

Final US-082 validation:

- `cargo fmt --check`
- `cargo clippy --workspace --all-targets -- -D warnings`
- `cargo test --workspace` — 68 CLI tests and 99 Symphony tests passed
- `scripts/validate-changeset-rebuild.sh` — restored 56 stories and passing
  US-073..US-081 proof
- Live-versus-rebuilt comparison — no E09 status/proof differences
- Live and rebuilt audits — entropy `0/100`
- Focused `review_finding` suite — 4 CLI regressions and 1 Symphony regression
- `! rg -n -- '--commit' docs/GLOSSARY.md`
- `bash -n scripts/validate-changeset-rebuild.sh`
- `git diff --check`

## Completed Review Passes

- [x] Proposal acceptance/rejection and recurrence classification
- [x] Story dependency and story-to-backlog mutation/replay parity
- [x] Atomic story completion, concurrency, and failure boundaries
- [x] Legacy reconciliation and schema migration compatibility
- [x] Outcome scheduling and daily health calculations
- [x] Symphony isolated and lightweight copied-database lifecycle integration
- [x] CLI argument/error behavior and documentation parity
- [x] Committed changeset integrity and full live-versus-rebuilt comparison
- [x] Final branch-wide changed-line hazard, test-gap, and provenance audit

## Post-US-082 Review Findings

All four findings in this section were resolved by US-083. Their original
cause/effect descriptions remain as review history.

### F-014 — P1 — One legacy resolver link disables precise ordering for every new link

**Location**

- `crates/harness-cli/src/infrastructure.rs:4933-4955`

**What happens**

The completion query uses nanosecond ordering only when *all* resolver links
have `linked_at_unix_ns`. If one historical link has `NULL`, the whole story
falls back to second-resolution text timestamps, including links and traces
that do have precise ordering.

Concrete cause and effect:

1. An upgraded story already resolves backlog A. Its legacy link is
   `10:00:00` with no nanosecond value.
2. At `11:00:00.100`, the story is linked to backlog B by the new code, which
   records nanosecond order `100` in addition to displayed time `11:00:00`.
3. At `11:00:00.200`, implementation trace T is recorded with nanosecond order
   `200`. T is unambiguously after the newest link.
4. Because backlog A's old link is `NULL`, the query ignores both new
   nanosecond values and checks `trace.created_at > MAX(linked_at)`.
5. Both displayed values are `11:00:00`, so strict text comparison is false.
6. `story complete` rejects valid proof even though the database contains
   enough information to establish its order.

The US-082 regression test covers an all-precise story. It does not cover the
mixed state produced naturally when a pre-v12 story receives another resolver
link after upgrading.

**Required correction**

- Compare against the newest resolver link as one ordered boundary. If that
  boundary has nanoseconds, use its nanoseconds; use the strict seconds
  fallback only when the newest boundary itself is legacy.
- Add live and replay tests for legacy-only, precise-only, and mixed resolver
  link sets, including same-second before-link and after-link traces.

### F-015 — P2 — Migration 012 does not backfill structured rejection reasons

**Location**

- `scripts/schema/012-review-finding-closure.sql:4`
- `crates/harness-cli/src/infrastructure.rs:3665-3677`

**What happens**

Migration 012 adds `backlog.rejection_reason`, but leaves every already
rejected occurrence at `NULL`. Runtime comparison masks this by parsing the
legacy `rejection_reason: ...` notes line. A rebuild, however, can populate the
new column from the historical proposal-decision operation.

Concrete cause and effect:

1. Before upgrading, proposal P is rejected with reason `not useful yet`; the
   reason exists in notes and in its semantic operation.
2. The live database applies migration 012. P's new column remains `NULL`.
3. A clean database replays the same operation through the v12 handler. P's
   new column becomes `not useful yet`.
4. Live and rebuilt databases now disagree on durable structured state even
   though they came from the same history.
5. Any later query, export, or invariant that reads the structured column
   directly sees different results depending on whether the database was
   upgraded or rebuilt.

**Required correction**

- Backfill `rejection_reason` from the exact first legacy reason line during
  migration, or explicitly normalize both upgraded and rebuilt rows to the
  same representation.
- Add a v11-to-v12 migration fixture containing a rejected keyed proposal and
  compare it with a clean replay of the same decision.

### F-016 — P1 — Rebuild validation can select an unrelated stale binary

**Location**

- `scripts/validate-changeset-rebuild.sh:8-14`

**What happens**

When `HARNESS_CLI` is not supplied, the validator chooses
`target/debug/harness-cli` whenever its filesystem modification time is newer
than the checked-in binary. Modification time does not establish which source
revision produced an executable.

Concrete cause and effect:

1. A developer builds an older commit, producing a debug binary.
2. They switch back to this branch or edit the source without rebuilding.
3. The old executable still has a newer mtime than `scripts/bin/harness-cli`.
4. The validator silently runs the old executable against the new changesets.
5. The result can be a false failure, or worse, a false pass that never
   exercises the code under review.

This script is cited as durable closure proof, so an unproven binary/source
relationship invalidates the proof boundary.

**Required correction**

- Make the executable explicit and fail if it is absent, or build/run the
  workspace package as part of validation.
- Print the selected command and a source/version identity in validation
  output.
- Add a shell test proving that an arbitrary newer file cannot silently become
  the validation subject.

### F-017 — P2 — Validator treats legitimate later verification as corruption

**Location**

- `scripts/validate-changeset-rebuild.sh:73-93`

**What happens**

The validator hardcodes the current `last_verified_at` value for each E09
story. `story verify`, however, is a repeatable semantic operation whose newest
timestamp should replace the previous one.

Concrete cause and effect:

1. US-073 currently rebuilds with passing proof at `2026-07-10 10:24:28`.
2. A maintainer reruns its checks tomorrow and records another legitimate
   passing `story.verify` operation.
3. Replay correctly produces the newer `last_verified_at`.
4. The validator still expects the July 10 literal and exits with
   `rebuilt proof mismatch`.
5. A healthy append-only history is therefore reported as broken until a
   second, unrelated shell-script edit updates the snapshot.

**Required correction**

- Assert proof meaning (`pass` and a non-null timestamp), and separately test
  exact timestamp replay in focused unit/integration fixtures.
- If exact repository snapshots are intentionally required, derive them from
  a versioned manifest generated with the changeset rather than duplicating
  mutable lifecycle values inside shell code.

## US-083 Closure Evidence

- `proof_audit_mixed_resolver_semantic_history_matches_after_replay` proves
  same-second before/after behavior when legacy and precise links coexist.
- `post_review_migration_backfills_exact_legacy_rejection_reason` proves a v11
  rejected occurrence migrates to exact structured state.
- `cargo test --workspace` passed: 70 Harness CLI tests and 99 Symphony tests.
- `cargo clippy --workspace --all-targets -- -D warnings` passed.
- `cargo fmt --check`, `bash -n scripts/validate-changeset-rebuild.sh`, and
  `git diff --check` passed.
- The source-matched rebuild restored 57 stories, including passing US-083
  proof and the US-082 -> US-083 dependency.
- Live and rebuilt Harness audits both report entropy `0/100`.

## Post-US-083 Proof-Audit Findings

### F-018 — P1 — Mixed resolver ordering is claimed replay-safe but never replayed

**Location**

- `docs/stories/epics/E09-self-improving-harness-lifecycle/US-083-post-review-correctness-closure/validation.md:7`
- `crates/harness-cli/src/infrastructure.rs:8441-8477`

**What happens**

The acceptance matrix requires the mixed legacy/new resolver case to work
“live and after replay.” The only mixed test creates one repository, inserts
rows directly, and completes the story in that same repository. It never emits
or applies a changeset and never evaluates the completion query in a rebuilt
database.

Concrete cause and effect:

1. The test inserts a legacy link, a precise link, and two traces directly.
2. It proves the live query rejects nanosecond `150` and accepts `300`.
3. No replay repository is created inside this test.
4. The older `review_finding_resolver_link_order_is_precise_and_replayable`
   test replays one precise link, not the mixed state that caused F-014.
5. The ledger therefore marks the required replay branch closed without
   executing it.

**Required correction**

- Materialize the mixed link/trace history through semantic operations, replay
  it into a fresh database, and assert the same before/after completion result.
- Make the test compare the selected proof UID and closed backlog set across
  live and replayed databases.

### F-019 — P2 — Validator executable acceptance text contradicts implemented behavior

**Location**

- `docs/stories/epics/E09-self-improving-harness-lifecycle/US-083-post-review-correctness-closure/validation.md:9`
- `scripts/validate-changeset-rebuild.sh:8-11`

**What happens**

The acceptance matrix says validation must “fail without explicit executable
identity.” The script intentionally does the opposite: with no `HARNESS_CLI`,
it builds and runs the workspace binary. The design document permits this
build/run path, so the implementation and its own acceptance matrix disagree.

Concrete cause and effect:

1. An operator unsets `HARNESS_CLI`.
2. The acceptance row predicts a failure.
3. The script runs `cargo build -p harness-cli` and succeeds.
4. Reviewers cannot tell whether the missing failure is a test omission or the
   documented contract is stale.

There is also no shell regression for either the default build path or the
explicit override path, despite F-016 requiring proof that a newer unrelated
file cannot silently become the validation subject.

**Required correction**

- Align the acceptance matrix with the chosen contract: source-build by
  default, explicit override when supplied.
- Add shell coverage for default build selection, explicit override, missing
  override, and an unrelated newer executable.

### F-020 — P2 — Later verification compatibility is inferred, not tested

**Location**

- `docs/stories/epics/E09-self-improving-harness-lifecycle/US-083-post-review-correctness-closure/validation.md:10`
- `scripts/validate-changeset-rebuild.sh:79-85`

**What happens**

F-017 requires a later valid `story.verify` operation to rebuild successfully.
No test appends a second verification operation or runs the validator against
that history. The shell condition was loosened, but the claimed lifecycle
scenario remains unexecuted.

Concrete cause and effect:

1. Current changesets contain one proof timestamp per historical story.
2. The validator sees those unchanged timestamps and passes.
3. No fixture appends a newer `story.verify` for the same story.
4. Ordering, overwrite behavior, and validator acceptance of the newest proof
   are therefore not demonstrated together.

**Required correction**

- Add a temporary changeset fixture with two passing verification operations
  for one story and different valid timestamps.
- Rebuild it and assert that the later timestamp wins and the repository-level
  proof validator still passes.

### F-021 — P2 — US-083 closure traces contain malformed list evidence

**Location**

- `.harness/changesets/run_1783743300_us083_post_review_closure.changeset.jsonl`
  (`trace.add` operations for traces 229 and 230)

**What happens**

JSON arrays were passed to CLI options that expect comma-separated lists. The
CLI split the JSON text at commas and stored quote/bracket fragments as list
items. Trace 230 also stores the literal string `"[]"` as one error instead of
an empty errors array.

Concrete runtime evidence:

```text
trace 230 actions_taken =
["[\"ran focused regression tests\"", "...", "\"prepared fresh rebuild validation\"]"]

trace 230 errors = ["[]"]
```

Cause and effect:

1. The trace scorer sees non-empty JSON arrays and grants detailed tier.
2. Humans and downstream queries see syntax fragments rather than clean action
   or file values.
3. `errors=["[]"]` falsely records an error while visually resembling “none.”
4. The high-risk closure evidence passes mechanically but is semantically
   malformed.

**Required correction**

- Append a corrected detailed trace using the CLI's actual CSV contract; keep
  the malformed historical traces rather than deleting them.
- Add CLI validation or documented examples that reject/detect JSON-array text
  passed to CSV options.
- Ensure an empty error list is stored as `[]`, not `["[]"]`.

### F-022 — P1 — Rebuild proof validation accepts arbitrary non-timestamp text

**Location**

- `scripts/validate-changeset-rebuild.sh:79-85`

**What happens**

The Bash pattern `pass\|?*` checks only that at least one character follows
`pass|`. It does not validate a timestamp. A corrupt replay value such as
`pass|garbage` satisfies the condition.

Concrete cause and effect:

1. A malformed or manually authored changeset writes
   `last_verified_result=pass` and `last_verified_at=garbage`.
2. SQLite concatenates it as `pass|garbage`.
3. `[[ "$actual" != pass\|?* ]]` evaluates false, so the validator accepts it.
4. The audit also reports the story verified because it checks the result, not
   timestamp syntax.
5. The rebuild can report zero entropy while durable proof time is invalid.

US-082 and US-083 are checked even more weakly: only their result is queried,
so a missing or invalid verification timestamp is invisible.

**Required correction**

- Validate `last_verified_at` with SQLite date parsing plus an exact accepted
  storage format, rather than a non-empty shell glob.
- Apply the same timestamp requirement to US-082 and US-083.
- Add corrupt/missing/valid timestamp fixtures and prove only the valid replay
  passes.

## US-084 Closure Evidence

- `proof_audit_mixed_resolver_semantic_history_matches_after_replay` applies
  legacy and precise links/traces as semantic operations to live and replay
  repositories, then compares rejection and completion results.
- `proof_audit_json_list_input_is_normalized_instead_of_split_into_fragments`
  proves JSON-list CLI input becomes valid JSON arrays, including `[]`.
- `scripts/test-validate-changeset-rebuild.sh` passed default-build, explicit
  override, missing override, unrelated newer executable, later verification,
  garbage timestamp, and missing timestamp scenarios.
- Version 2 `story.verify` replay now requires canonical
  `YYYY-MM-DD HH:MM:SS`; the rebuild validator checks the same invariant for
  US-073 through US-084.
- Detailed corrective trace 232 contains six clean actions and an actual empty
  errors array; malformed traces 229 and 230 remain immutable history.
- `cargo test --workspace` passed 71 Harness CLI tests and 99 Symphony tests.
- All-target clippy, formatting, Bash syntax, and diff checks passed.
- Fresh rebuild restored 58 stories; live and rebuilt audits report entropy
  `0/100`.

## Post-US-084 Causality-Audit Findings

### F-023 — P2 — The unrelated-newer-binary test cannot enter the selection path

**Location**

- `scripts/test-validate-changeset-rebuild.sh:27-37`

**What happens**

The test creates `$TMP_DIR/newer-unrelated-cli`, but the validator never scans
that directory or filename. It only uses explicit `HARNESS_CLI` or the fixed
workspace `target/debug/harness-cli` built by the script.

Concrete cause and effect:

1. A fake executable is created in an arbitrary temporary path.
2. `HARNESS_CLI` is unset.
3. No configuration points the validator at the fake path.
4. The validator selects its fixed workspace path exactly as it would if the
   fake file did not exist.
5. The assertion therefore cannot fail under the old mtime-selection defect
   and does not prove the stated regression boundary.

**Required correction**

- Extract binary selection into a function with injectable installed/debug
  candidates, or run the validator inside an isolated fixture root containing
  both exact candidate paths.
- Prove the source-build path wins even when the installed candidate has a
  newer mtime, and separately prove an explicit override wins by authority.

### F-024 — P2 — Invalid-proof shell fixtures fail before exercising validator SQL

**Location**

- `scripts/test-validate-changeset-rebuild.sh:60-88`
- `crates/harness-cli/src/infrastructure.rs:4492-4510`

**What happens**

The garbage and missing timestamp fixtures use version 2 `story.verify`.
Changeset replay now rejects those operations before the rebuilt database or
the validator's canonical timestamp query exists. The shell test passes, but
not for the reason its acceptance claim names.

Concrete cause and effect:

1. The test invokes the repository validator with a garbage v2 operation.
2. `db rebuild` returns `verified_at must use ...` from the operation handler.
3. `validate-changeset-rebuild.sh` exits immediately because rebuild failed.
4. Its SQLite proof-validation loop never runs.
5. The test is evidence for operation validation, not for the separate
   repository-level proof invariant.

**Required correction**

- Test operation rejection directly as an operation-parser/replay test.
- Test the validator query independently against rebuilt fixture databases
  containing valid, missing, and malformed proof rows, so each defense layer
  has causal coverage.

### F-025 — P2 — JSON-list normalization still fragments non-string arrays

**Location**

- `crates/harness-cli/src/domain.rs:1211-1223`

**What happens**

Normalization attempts only `serde_json::from_str::<Vec<String>>`. JSON arrays
with a number, object, or malformed element fail that parse and silently fall
back to comma splitting—the original corruption mechanism.

Concrete cause and effect:

1. A caller supplies `--errors '["timeout",1]'`.
2. The input is valid JSON but not `Vec<String>`.
3. Parsing fails and the fallback splits on the comma.
4. Harness stores fragments such as `["timeout"` and `1]` as strings.
5. Trace scoring still sees non-empty evidence instead of rejecting invalid
   typed input.

**Required correction**

- If trimmed input begins with `[` or `{`, require valid JSON of the supported
  shape and return a typed error instead of falling back to CSV.
- Add mixed-type, object, malformed-array, valid-string-array, empty-array, and
  ordinary CSV tests.

### F-026 — P2 — Version 2 verification accepts non-canonical timestamp text

**Location**

- `crates/harness-cli/src/infrastructure.rs:4494-4502`

**What happens**

`NaiveDateTime::parse_from_str` validates the date value but does not enforce
the exact storage representation promised by the error message and validator.

Concrete runtime proof:

```text
story.verify version=2 verified_at="2099-1-2 3:4:5"
db rebuild: accepted
stored last_verified_at: 2099-1-2 3:4:5
```

The repository validator later rejects that row because it requires exactly
19 characters, so operation replay and repository validation implement
different definitions of “canonical.”

**Required correction**

- Parse and round-trip format the timestamp, then require formatted output to
  equal the original string.
- Share one canonical timestamp helper between `story.verify`,
  `story.complete`, and focused validation tests.

### F-027 — P1 — Version 2 story completion bypasses proof timestamp validation

**Location**

- `crates/harness-cli/src/infrastructure.rs:4519-4528`

**What happens**

`story.complete` writes `completed_at` into `last_verified_at`, but unlike the
new `story.verify` handler it accepts missing or arbitrary text for version 2.
This is another semantic operation capable of creating the invalid proof state
F-022 was meant to prevent.

Concrete runtime proof:

```text
story.complete version=2 completed_at="garbage"
db rebuild: accepted
stored story state: implemented|garbage
```

Cause and effect:

1. A malformed v2 completion operation is replayed.
2. The handler stores `garbage` as verification time and marks the story
   implemented.
3. Direct changeset apply succeeds even though durable proof is corrupt.
4. Only the outer repository validator catches it later; consumers that apply
   one changeset without that script retain invalid state.

**Required correction**

- Require canonical `completed_at` for version 2 `story.complete`, using the
  same helper as `story.verify`.
- Preserve legacy fallback only for version 1 operations.
- Add missing, garbage, non-canonical, and canonical completion replay tests.

### F-028 — P1 — Version 2 backlog completion accepts corrupt lifecycle time

**Location**

- `crates/harness-cli/src/infrastructure.rs:4529-4543`

**What happens**

`backlog.complete` has the same unchecked `completed_at` fallback as
`story.complete`. This timestamp controls both `implemented_at` and
`closed_at`, which recurrence classification uses to decide whether later
evidence is a regression.

Concrete runtime proof:

```text
backlog.complete version=2 completed_at="garbage"
db changeset apply: accepted
stored backlog state: implemented|garbage
```

Cause and effect:

1. A malformed completion operation is applied to an otherwise valid rebuilt
   database.
2. Harness marks the backlog implemented and stores `garbage` as closure time.
3. SQLite date comparisons against the closure boundary no longer have defined
   lifecycle meaning.
4. Recurrence suppression/regression can diverge even though changeset apply
   reported success.

**Required correction**

- Require canonical `completed_at` for version 2 `backlog.complete` using the
  shared timestamp helper.
- Keep the version 1 fallback only for legacy compatibility.
- Add apply and rebuild parity tests covering missing, invalid,
  non-canonical, and canonical backlog completion timestamps.

### F-029 — P1 — Other version 2 lifecycle operations still accept arbitrary timestamps

**Location**

- `crates/harness-cli/src/infrastructure.rs:4662-4684`
- `crates/harness-cli/src/infrastructure.rs:4714-4735`
- `crates/harness-cli/src/infrastructure.rs:4802-4834`
- `crates/harness-cli/src/infrastructure.rs:4844-4858`

**What happens**

Timestamp validation was added only to `story.verify`. Other version 2
operations write required lifecycle timestamps directly: outcome observations,
proposal decisions/evidence, interventions, traces, and audit episodes.

Concrete runtime proof:

```text
trace.add version=2 created_at="garbage"
db changeset apply: accepted
stored trace.created_at: garbage
```

Cause and effect:

1. A malformed v2 trace, decision, observation, or audit operation is applied.
2. Required timestamp text is stored without format validation.
3. Recurrence ordering, outcome schedules, audit episode history, and legacy
   fallback comparisons can no longer order the event reliably.
4. Changeset apply still reports success, and the repository validator checks
   only selected story proof timestamps.

**Required correction**

- Inventory every semantic-operation timestamp and classify its canonical
  storage format and legacy compatibility rule.
- Use shared required/optional canonical timestamp helpers for all version 2
  lifecycle operations, including nested evidence timestamps.
- Add table-driven apply/rebuild tests for each operation family so timestamp
  integrity is not fixed one handler at a time.

## US-085 Closure Evidence

- `semantic_integrity_rejects_noncanonical_timestamps_across_operation_families`
  covers canonical, garbage, unpadded, and invalid-date values across intake,
  backlog, intervention, trace, story verification/completion, backlog
  completion/outcomes/proposals, nested evidence, legacy capture, and audit
  episode operations.
- Version 2 story links and completion operations require exact stored time;
  version 1 fallback behavior remains available for committed legacy history.
- `semantic_integrity_json_like_lists_are_typed_and_csv_remains_supported`
  covers ordinary CSV, valid string arrays, empty arrays, mixed arrays, objects,
  and malformed JSON.
- The validator selection test uses exact isolated `target/debug` and
  `scripts/bin` candidates with the installed candidate newer; deterministic
  source-build selection wins. Explicit override and missing override are also
  covered.
- Operation-parser garbage/missing fixtures and direct `proof_is_valid`
  database mutations independently exercise both validation layers.
- `cargo test --workspace` passed 73 Harness CLI and 99 Symphony tests;
  all-target clippy, formatting, Bash syntax, and diff checks passed.
- Detailed traces 233 and 234 meet the high-risk evidence tier with true empty
  error arrays.
- Fresh rebuild restored 59 stories; live and rebuilt audits report entropy
  `0/100`.
