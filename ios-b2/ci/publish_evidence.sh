#!/bin/bash
set -euo pipefail
# Publish only explicit non-secret evidence files so public API readers can audit stdout.
evidence="$GITHUB_WORKSPACE/build-b2/evidence"
worktree="$RUNNER_TEMP/b2-evidence-tree"
if git ls-remote --exit-code origin refs/heads/b2-build-evidence >/dev/null 2>&1; then
  git fetch origin b2-build-evidence
  git worktree add -b b2-evidence-publish "$worktree" FETCH_HEAD
else
  git worktree add -b b2-evidence-publish "$worktree" HEAD
fi
mkdir -p "$worktree/docs/app-store-launch/ci/$GITHUB_RUN_ID"
cp -R "$evidence/." "$worktree/docs/app-store-launch/ci/$GITHUB_RUN_ID/"
cd "$worktree"
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add docs/app-store-launch/ci
git commit -m "docs(b2b): build evidence $GITHUB_RUN_ID [skip ci]"
git push origin HEAD:refs/heads/b2-build-evidence
