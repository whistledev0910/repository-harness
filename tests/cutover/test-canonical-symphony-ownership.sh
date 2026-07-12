#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ASSERT="$ROOT_DIR/tests/cutover/assert-canonical-symphony-ownership.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git init --bare -q "$tmp/origin.git"
git init -q -b main "$tmp/source"
git -C "$tmp/source" config user.name "E11 fixture"
git -C "$tmp/source" config user.email "e11-fixture@example.invalid"
printf 'standalone product\n' >"$tmp/source/README.md"
git -C "$tmp/source" add README.md
git -C "$tmp/source" commit -qm "fixture"
commit="$(git -C "$tmp/source" rev-parse HEAD)"
git -C "$tmp/source" tag symphony-v-test
git -C "$tmp/source" remote add origin "$tmp/origin.git"
git -C "$tmp/source" push -q origin main --tags
git --git-dir="$tmp/origin.git" symbolic-ref HEAD refs/heads/main
git clone -q "$tmp/origin.git" "$tmp/clone"

common=(
  SYMPHONY_EXPECTED_REPOSITORY=fixture/symphony
  SYMPHONY_EXPECTED_COMMIT="$commit"
  SYMPHONY_EXPECTED_TAG=symphony-v-test
  SYMPHONY_EXPECTED_BRANCH=main
)
# The fixture uses a local canonical origin, so rewrite it to an accepted URL
# only inside the clone; no network operation follows.
git -C "$tmp/clone" remote set-url origin git@github.com:fixture/symphony.git
env "${common[@]}" "$ASSERT" "$tmp/clone" --json | jq -e \
  '.clean == true and .forbidden_tracked_paths == 0 and .active_durable_databases == 0' >/dev/null

mkdir -p "$tmp/clone/.codex"
if env "${common[@]}" "$ASSERT" "$tmp/clone" >/dev/null 2>&1; then
  echo "canonical ownership verifier accepted a forbidden hidden directory" >&2
  exit 1
fi
rmdir "$tmp/clone/.codex"

printf 'dirty\n' >>"$tmp/clone/README.md"
if env "${common[@]}" "$ASSERT" "$tmp/clone" >/dev/null 2>&1; then
  echo "canonical ownership verifier accepted a dirty checkout" >&2
  exit 1
fi

echo "canonical Symphony ownership positive and negative fixtures passed"
