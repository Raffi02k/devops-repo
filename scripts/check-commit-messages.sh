#!/usr/bin/env bash
# Check that commit messages follow Conventional Commits.
# In a pull request, every commit in it is checked. Otherwise only the latest commit.
set -uo pipefail

if [ -n "${BASE_REF:-}" ]; then
  messages=$(git log --format=%s "origin/$BASE_REF..HEAD")
else
  messages=$(git log -1 --format=%s)
fi

fail=0
echo "==> Checking the commit messages"
while IFS= read -r message; do
  # Git's own messages for merges and reverts are fine as they are.
  if echo "$message" | grep -Eq '^(Merge|Revert) '; then
    continue
  fi
  if echo "$message" | grep -Eq '^(feat|fix|docs|chore|refactor|test|ci|build|style|perf)(\(.+\))?!?: .+'; then
    echo "  ok    $message"
  else
    echo "  FAIL  $message"
    fail=1
  fi
done <<< "$messages"

exit "$fail"