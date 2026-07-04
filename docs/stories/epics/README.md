# Epic Story Packets

Create epic folders here only when work begins or when product decisions need a
durable home.

Suggested naming:

```text
E01-domain-name/
E02-domain-name/
E03-domain-name/
```

Create the real epic names from the user-provided spec, not from this template.

## Active Epic Sequence

| Epic | Theme | Exit Signal |
| --- | --- | --- |
| `E04-symphony-cli-prerequisites` | Make `harness-cli` support copied DBs, semantic changesets, replay, and rebuild. | `harness.db` is a rebuildable local index over committed changesets. |
| `E05-symphony-local-runner` | Build the on-demand local workbench: doctor, work list, isolated prepare, run contract, result validation, and status. | `harness-symphony run <story-id> --prepare-only` satisfies the MVP acceptance criteria. |
| `E06-symphony-review-sync` | Make run artifacts reviewable and merged changesets syncable. | PR artifacts are reviewable and `sync` is idempotent. |
| `E07-symphony-automation` | Add lightweight tiny runs and later unattended automation. | Automation reuses the proven local run contract and sync model. |
