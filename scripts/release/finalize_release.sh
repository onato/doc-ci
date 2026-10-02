#!/usr/bin/env bash
# Commits the version bump and changelogs, then creates the GitHub release and tag.
# Run after the upload to Play succeeds.
set -euo pipefail
. "$(dirname "$0")/common.sh"

next_release="${1:?Usage: $0 <version> <notes-file> <play-notes-file>}"
notes_file="${2:?Usage: $0 <version> <notes-file> <play-notes-file>}"
play_notes_file="${3:?Usage: $0 <version> <notes-file> <play-notes-file>}"

git add "$VERSION_FILE" "$CHANGELOG_FILE" "$play_notes_file"
git commit -m "chore: release $next_release"
git push origin HEAD

# Prerelease until it's promoted from the internal track to production
gh release create "$next_release" \
  --target "$(git rev-parse HEAD)" \
  --title "$next_release" \
  --notes-file "$notes_file" \
  --prerelease
