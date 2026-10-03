#!/usr/bin/env bash
# Generates release notes from the conventional commits between two refs.
#
#   changelog.sh <from> [<to>]          Markdown for GitHub releases and CHANGELOG.md
#   changelog.sh --play <from> [<to>]   Plain text for Google Play (max 500 characters)
set -euo pipefail
. "$(dirname "$0")/common.sh"

format=markdown
if [[ "${1:-}" == "--play" ]]; then
  format=play
  shift
fi
from="${1:?Usage: $0 [--play] <from> [<to>]}"
to="${2:-HEAD}"

[[ $format == markdown ]] && url=$(repo_url)

breaking="" features="" fixes="" performance=""
seen=$'\n'

while read -r sha; do
  [[ -z "$sha" ]] && continue
  subject=$(commit_subject "$sha")
  body=$(commit_body "$sha")
  type=$(commit_type "$subject")
  description=$(commit_description "$subject" || true)
  description="$(tr '[:lower:]' '[:upper:]' <<<"${description:0:1}")${description:1}"

  # A follow-up commit often reuses the original subject; list each change once
  if [[ -n "$type" && "$seen" == *$'\n'"$type:$description"$'\n'* ]]; then
    continue
  fi
  seen+="$type:$description"$'\n'

  if [[ $format == play ]]; then
    line="- $description"
  else
    refs=$(issue_refs "$subject" "$body")
    line="- $description${refs:+ ($refs)} ([${sha:0:7}]($url/commit/$sha))"
  fi

  if is_breaking "$subject" "$body"; then
    breaking+="$line"$'\n'
  else
    case "$type" in
    feat) features+="$line"$'\n' ;;
    fix) fixes+="$line"$'\n' ;;
    perf) performance+="$line"$'\n' ;;
    esac
  fi
done < <(commits_between "$from" "$to")

print_section() {
  [[ -z "$2" ]] && return
  if [[ $format == play ]]; then
    printf '%s' "$2"
  else
    printf '### %s\n\n%s\n' "$1" "$2"
  fi
}

{
  print_section "Breaking changes" "$breaking"
  print_section "Features" "$features"
  print_section "Bug fixes" "$fixes"
  print_section "Performance" "$performance"
} | if [[ $format == play ]]; then head -c 500; else cat; fi
