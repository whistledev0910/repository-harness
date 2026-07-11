# Overview

## Current Behavior

Repeated friction and interventions generate proposals regardless of whether
the evidence came from production work or a smoke fixture. A production
friction pattern can also remain actionable after later durable state proves
the missing capability is present.

Concrete examples are synthetic proposal items `#6` and `#7`, plus the current
validation-provider proposal generated from traces `109` through `111` even
though `US-072` registered five present validation providers.

## Target Behavior

Proposal generation retains all raw evidence but excludes synthetic evidence by
default and explains when later current state causally retires an older signal.
New qualifying evidence after retirement becomes a regression rather than
silently disappearing.

## Affected Users

- Harness operators reviewing daily improvement proposals.
- Agents recording trace and intervention evidence.

## Affected Product Docs

- `docs/IMPROVEMENT_PROTOCOL.md`
- `docs/TRACE_SPEC.md`
- `docs/HARNESS_MATURITY.md`

## Non-Goals

- Delete synthetic or obsolete evidence.
- Infer that arbitrary free-text friction is resolved without a deterministic
  resolver.
- Bulk-decide proposals on behalf of the operator.
