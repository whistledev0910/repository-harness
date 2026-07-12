#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

validate_observation() { "$ROOT_DIR/tests/cutover/assert-us100-observation-record.sh" "$1" >/dev/null; }

jq -n '
  (now | floor) as $now |
  ($now - 604801) as $start |
  {
  "schema":"e11-us100-observation-window-v1","owner":"hoangnb24","required_calendar_days":7,
  "started_at":($start | strftime("%Y-%m-%dT%H:%M:%SZ")),
  "eligible_end_at":($start + 604800 | strftime("%Y-%m-%dT%H:%M:%SZ")),
  "closed_at":($now - 1 | strftime("%Y-%m-%dT%H:%M:%SZ")),
  "real_development_cycle":{"completed":true,"completed_at":($start + 1 | strftime("%Y-%m-%dT%H:%M:%SZ")),"evidence":"cycle-1"},
  "blocking_signals":[
    {"class":"protocol_mismatch","observed":false,"recovery":"compatible release tuple"},
    {"class":"state_loss_or_duplication","observed":false,"recovery":"paired state epoch"},
    {"class":"installer_or_release_regression","observed":false,"recovery":"installer/release revert"},
    {"class":"wrong_owner_active_suggestion","observed":false,"recovery":"selector ownership fence"},
    {"class":"platform_failure","observed":false,"recovery":"platform artifact withdrawal"}],
  "repairs":[],"rollback_artifacts_retained":true,"closure_decision":"complete_without_rollback"
}' >"$tmp/valid.json"
validate_observation "$tmp/valid.json"

jq '.closed_at = .started_at' "$tmp/valid.json" >"$tmp/early.json"
if validate_observation "$tmp/early.json"; then
  echo "observation gate accepted fewer than seven calendar days" >&2; exit 1
fi
jq '.started_at="2099-01-01T00:00:00Z" | .eligible_end_at="2099-01-08T00:00:00Z" | .closed_at="2099-01-08T00:00:00Z" | .real_development_cycle.completed_at="2099-01-02T00:00:00Z"' "$tmp/valid.json" >"$tmp/future.json"
if validate_observation "$tmp/future.json"; then
  echo "observation gate accepted a future window" >&2; exit 1
fi
jq '.real_development_cycle.completed_at="2000-01-01T00:00:00Z"' "$tmp/valid.json" >"$tmp/pre-window-cycle.json"
if validate_observation "$tmp/pre-window-cycle.json"; then
  echo "observation gate accepted a cycle completed before the window" >&2; exit 1
fi
jq '.eligible_end_at = .started_at' "$tmp/valid.json" >"$tmp/forged-eligible-end.json"
if validate_observation "$tmp/forged-eligible-end.json"; then
  echo "observation gate accepted a forged eligible end" >&2; exit 1
fi
jq '.real_development_cycle.completed=false' "$tmp/valid.json" >"$tmp/no-cycle.json"
if validate_observation "$tmp/no-cycle.json"; then
  echo "observation gate accepted a missing real development cycle" >&2; exit 1
fi
jq '.blocking_signals[0].observed=true' "$tmp/valid.json" >"$tmp/signal.json"
if validate_observation "$tmp/signal.json"; then
  echo "observation gate accepted a blocking signal" >&2; exit 1
fi
jq '.repairs=[{"at":"2026-07-15T00:00:00Z"}]' "$tmp/valid.json" >"$tmp/repair.json"
if validate_observation "$tmp/repair.json"; then
  echo "observation gate accepted a window that was not restarted after repair" >&2; exit 1
fi

echo "US-100 observation schema rejects early, future, cycle-free, pre-window-cycle, forged-end, signaled, and repaired windows"
