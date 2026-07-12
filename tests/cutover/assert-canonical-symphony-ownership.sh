#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <fresh-symphony-clone> [--json]" >&2
  exit 2
}

test "$#" -ge 1 && test "$#" -le 2 || usage
REPO="$1"
FORMAT="${2:-}"
test -z "$FORMAT" || test "$FORMAT" = "--json" || usage

EXPECTED_REPOSITORY="${SYMPHONY_EXPECTED_REPOSITORY:-hoangnb24/symphony}"
EXPECTED_COMMIT="${SYMPHONY_EXPECTED_COMMIT:-2357bc4f333a12794f975a46dbc0df96599fe4c0}"
EXPECTED_TAG="${SYMPHONY_EXPECTED_TAG:-symphony-v0.1.0}"
EXPECTED_BRANCH="${SYMPHONY_EXPECTED_BRANCH:-main}"

fail() { echo "canonical Symphony ownership failed: $*" >&2; exit 1; }
for command in git jq; do
  command -v "$command" >/dev/null || fail "required command is missing: $command"
done
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a Git checkout: $REPO"

head="$(git -C "$REPO" rev-parse HEAD)"
branch="$(git -C "$REPO" branch --show-current)"
origin="$(git -C "$REPO" remote get-url origin)"
case "$origin" in
  git@github.com:"$EXPECTED_REPOSITORY".git|https://github.com/"$EXPECTED_REPOSITORY".git) ;;
  *) fail "origin is not the canonical repository: $origin" ;;
esac
test "$head" = "$EXPECTED_COMMIT" || fail "HEAD $head is not published commit $EXPECTED_COMMIT"
test "$branch" = "$EXPECTED_BRANCH" || fail "checkout branch $branch is not $EXPECTED_BRANCH"
git -C "$REPO" show-ref --verify --quiet "refs/tags/$EXPECTED_TAG" || fail "published tag is absent"
test "$(git -C "$REPO" rev-list -n 1 "$EXPECTED_TAG")" = "$EXPECTED_COMMIT" || fail "published tag points elsewhere"
test "$(git -C "$REPO" rev-parse "origin/$EXPECTED_BRANCH")" = "$EXPECTED_COMMIT" || fail "origin/$EXPECTED_BRANCH differs from the published commit"
test -z "$(git -C "$REPO" status --porcelain)" || fail "fresh checkout is dirty"

tracked_forbidden="$(git -C "$REPO" ls-files | grep -E '(^|/)(\.agents|\.codex|\.impeccable|\.harness/changesets)(/|$)' || true)"
test -z "$tracked_forbidden" || fail "canonical tree tracks a forbidden runtime/tool path: $tracked_forbidden"
for hidden in .agents .codex .impeccable .harness/changesets; do
  test ! -e "$REPO/$hidden" || fail "fresh canonical checkout contains $hidden"
done

# A fresh canonical product clone must not arrive with an operational Harness
# database. Target-owned historical story packets remain source evidence; the
# active work queue, if an operator initializes one later, is local-only.
for db in harness.db .harness/harness.db .harness/state.db .harness/symphony.db; do
  test ! -e "$REPO/$db" || fail "fresh canonical checkout activates durable state at $db"
done

if test "$FORMAT" = "--json"; then
  jq -n \
    --arg repository "$EXPECTED_REPOSITORY" \
    --arg commit "$head" \
    --arg branch "$branch" \
    --arg tag "$EXPECTED_TAG" \
    '{schema:"e11-us100-canonical-target-ownership-v1",repository:$repository,commit:$commit,branch:$branch,tag:$tag,clean:true,forbidden_tracked_paths:0,active_durable_databases:0}'
else
  echo "canonical Symphony ownership passed at $EXPECTED_BRANCH@$EXPECTED_COMMIT ($EXPECTED_TAG)"
fi
