#!/usr/bin/env bash
# Checks that every commit after <base> is a conventional commit, and warns when
# a feat/fix/perf commit doesn't reference an issue (e.g. "Fixes #12").
set -euo pipefail
. "$(dirname "$0")/common.sh"

base="${1:?Usage: $0 <base-ref>}"
failed=0

while read -r sha; do
  [[ -z "$sha" ]] && continue
  subject=$(commit_subject "$sha")
  type=$(commit_type "$subject")

  if [[ -z "$type" || " $ALLOWED_TYPES " != *" $type "* ]]; then
    echo "::error::${sha:0:7} \"$subject\" isn't a conventional commit (type: description). Allowed types: $ALLOWED_TYPES"
    failed=1
  elif [[ "$type" =~ ^(feat|fix|perf)$ && -z "$(issue_refs "$subject" "$(commit_body "$sha")")" ]]; then
    echo "::warning::${sha:0:7} \"$subject\" doesn't reference an issue. Add e.g. \"Fixes #12\" to the commit message."
  fi
done < <(commits_between "$base")

exit $failed
