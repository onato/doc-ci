#!/usr/bin/env bash
# Works out from the conventional commits since the last release whether a new
# release is needed (feat → minor, fix/perf → patch, breaking → major). If so,
# bumps the version, prepends the release to the changelog and writes the
# Play release notes.
set -euo pipefail
. "$(dirname "$0")/common.sh"

current_release=$(latest_release)
bump=""

while read -r sha; do
  [[ -z "$sha" ]] && continue
  subject=$(commit_subject "$sha")
  if is_breaking "$subject" "$(commit_body "$sha")"; then
    bump=major
    break
  fi
  case "$(commit_type "$subject")" in
  feat) bump=minor ;;
  fix | perf) [[ -z "$bump" ]] && bump=patch ;;
  esac
done < <(commits_between "$current_release")

output() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "$1" >>"$GITHUB_OUTPUT"; fi
}

if [[ -z "$bump" ]]; then
  echo "No feat/fix/perf commits since $current_release, no release needed"
  output "needs_release=false"
  exit 0
fi

IFS=. read -r major minor patch <<<"$current_release"
case "$bump" in
major) next_release="$((major + 1)).0.0" ;;
minor) next_release="$major.$((minor + 1)).0" ;;
patch) next_release="$major.$minor.$((patch + 1))" ;;
esac
version_code=$(($(get_property "$VERSION_FILE" versionCode) + 1))

echo "Releasing $current_release -> $next_release (version code $version_code)"

set_property "$VERSION_FILE" versionName "$next_release"
set_property "$VERSION_FILE" versionCode "$version_code"

scripts_dir="$(dirname "$0")"
notes_file="${RUNNER_TEMP:-$(mktemp -d)}/release-notes.md"
"$scripts_dir/changelog.sh" "$current_release" >"$notes_file"

play_notes_dir="$FASTLANE_DIR/metadata/android/en-US/changelogs"
mkdir -p "$play_notes_dir"
"$scripts_dir/changelog.sh" --play "$current_release" >"$play_notes_dir/$version_code.txt"

{
  echo "# Changelog"
  echo
  echo "## [$next_release]($(repo_url)/compare/$current_release...$next_release) ($(date +%Y-%m-%d))"
  echo
  cat "$notes_file"
  if [[ -f "$CHANGELOG_FILE" ]]; then tail -n +3 "$CHANGELOG_FILE"; fi
} >"$CHANGELOG_FILE.tmp"
mv "$CHANGELOG_FILE.tmp" "$CHANGELOG_FILE"

output "needs_release=true"
output "next_release=$next_release"
output "notes_file=$notes_file"
output "play_notes_file=$play_notes_dir/$version_code.txt"
