#!/usr/bin/env bash
set -euo pipefail

RECORD="${1:-}"
test -n "$RECORD" && test -f "$RECORD" || {
  echo "usage: $0 <observation-window.json>" >&2
  exit 2
}

jq -e --argjson now "$(date -u +%s)" '
  .schema == "e11-us100-observation-window-v1" and
  .owner == "hoangnb24" and .required_calendar_days == 7 and
  (.started_at | fromdateiso8601) > 0 and
  (.started_at | fromdateiso8601) <= $now and
  (.eligible_end_at | fromdateiso8601) == ((.started_at | fromdateiso8601) + 604800) and
  (.closed_at | fromdateiso8601) >= (.eligible_end_at | fromdateiso8601) and
  (.closed_at | fromdateiso8601) <= $now and
  .real_development_cycle.completed == true and
  (.real_development_cycle.completed_at | fromdateiso8601) >= (.started_at | fromdateiso8601) and
  (.real_development_cycle.completed_at | fromdateiso8601) <= (.closed_at | fromdateiso8601) and
  (.real_development_cycle.evidence | strings | length) > 0 and
  ([.blocking_signals[].class] | sort) == ([
    "installer_or_release_regression", "platform_failure", "protocol_mismatch",
    "state_loss_or_duplication", "wrong_owner_active_suggestion"
  ] | sort) and
  all(.blocking_signals[]; .observed == false and (.recovery | strings | length) > 0) and
  (.repairs | type) == "array" and (.repairs | length) == 0 and
  .rollback_artifacts_retained == true and
  .closure_decision == "complete_without_rollback"
' "$RECORD" >/dev/null || {
  echo "US-100 observation record is not eligible for closure: $RECORD" >&2
  exit 1
}

echo "US-100 observation record is eligible for closure"
