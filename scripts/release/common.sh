# Shared helpers for the release scripts. These scripts are the same in every
# DOC app repo; per-app differences go in the env vars below.

VERSION_FILE="${VERSION_FILE:-version.properties}"
FASTLANE_DIR="${FASTLANE_DIR:-fastlane}"
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"

TYPE_RE='^([a-z]+)(\([^)]*\))?(!)?: (.+)$'
ALLOWED_TYPES="feat fix perf refactor revert docs style test build ci chore"

# Most recent x.y.z tag reachable from HEAD
latest_release() {
  git describe --tags --abbrev=0 --match '[0-9]*.[0-9]*.[0-9]*'
}

# Non-merge commits after $1 up to $2 (default HEAD), oldest first
commits_between() {
  git rev-list --no-merges --reverse "$1".."${2:-HEAD}"
}

commit_subject() { git show -s --format=%s "$1"; }
commit_body() { git show -s --format=%b "$1"; }

# Prints the conventional commit type, or nothing if the subject isn't conventional
commit_type() {
  if [[ "$1" =~ $TYPE_RE ]]; then echo "${BASH_REMATCH[1]}"; fi
}

# Description without the type prefix or a trailing "(#12)" added by squash merges
commit_description() {
  [[ "$1" =~ $TYPE_RE ]] && echo "${BASH_REMATCH[4]}" | sed -E 's/( \(#[0-9]+\))+$//'
}

is_breaking() {
  [[ "$1" =~ $TYPE_RE && -n "${BASH_REMATCH[3]}" ]] || grep -qE '^BREAKING[ -]CHANGE:' <<<"$2"
}

# Issue/PR references in a commit message, e.g. "#1, #4"
issue_refs() {
  printf '%s\n%s\n' "$1" "$2" | { grep -oE '#[0-9]+' || true; } | sort -t'#' -k2 -n -u | paste -sd, - | sed 's/,/, /g'
}

get_property() {
  sed -n "s/^$2=//p" "$1"
}

set_property() {
  local tmp
  tmp=$(mktemp)
  sed "s/^$2=.*/$2=$3/" "$1" >"$tmp" && mv "$tmp" "$1"
}

repo_url() {
  gh repo view --json url --jq .url
}
