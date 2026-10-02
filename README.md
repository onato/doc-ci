# doc-ci

Shared CI for the DOC Android apps: build and test on every push, automatic releases to the
Google Play internal track, and an automated code reviewer on pull requests.

This repo is public and must never contain secrets. Signing keys, passwords and Play
credentials live as secrets in each app repo and are passed in at run time.

## What an app repo needs

```
.github/workflows/build.yml        # calls android.yml (below)
.github/workflows/code-review.yml  # calls code-review.yml (below)
version.properties                 # versionCode and versionName, updated by CI
CHANGELOG.md                       # written by CI
fastlane/metadata/android/en-US/changelogs/  # Play release notes, written by CI
```

`app/build.gradle` reads `version.properties` and has a release signing config that only
applies when `UPLOAD_STORE_FILE` is set (see onato/doc-bat-recorder-tester for an example).

### `.github/workflows/build.yml`

```yaml
name: Build and deploy

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: build-${{ github.ref }}
  # Never cancel a run that may be uploading to Play or tagging a release
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

permissions:
  contents: write

jobs:
  android:
    uses: onato/doc-ci/.github/workflows/android.yml@v1
    with:
      package-name: nz.govt.doc.example
    secrets:
      UPLOAD_KEYSTORE_BASE64: ${{ secrets.UPLOAD_KEYSTORE_BASE64 }}
      UPLOAD_STORE_PASSWORD: ${{ secrets.UPLOAD_STORE_PASSWORD }}
      UPLOAD_KEY_ALIAS: ${{ secrets.UPLOAD_KEY_ALIAS }}
      UPLOAD_KEY_PASSWORD: ${{ secrets.UPLOAD_KEY_PASSWORD }}
      PLAYSTORE_JSON_CONTENTS: ${{ secrets.PLAYSTORE_JSON_CONTENTS }}
```

Secrets are passed by name rather than with `secrets: inherit`, so each workflow only gets what
it needs.

For a React Native app, add `android-dir: android`.

### `.github/workflows/code-review.yml`

```yaml
name: Code review

on:
  pull_request:
    types: [opened, synchronize, ready_for_review, reopened]

concurrency:
  group: code-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true

permissions:
  contents: read
  pull-requests: write
  issues: write
  id-token: write

jobs:
  review:
    uses: onato/doc-ci/.github/workflows/code-review.yml@v1
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

## Secrets (in each app repo)

| Secret | Value |
| --- | --- |
| `UPLOAD_KEYSTORE_BASE64` | the shared DOC upload keystore, base64-encoded |
| `UPLOAD_STORE_PASSWORD` | keystore password |
| `UPLOAD_KEY_ALIAS` | `doc-key-alias` |
| `UPLOAD_KEY_PASSWORD` | key password |
| `PLAYSTORE_JSON_CONTENTS` | the Play service account JSON key (`fastlane@department-of-conservation.iam.gserviceaccount.com`), base64-encoded |
| `CLAUDE_CODE_OAUTH_TOKEN` | from `claude setup-token`, for the code reviewer |

All DOC apps upload with the same key (`doc-upload-key.keystore`, alias `doc-key-alias`).
Google re-signs each app with its own app signing key, so sharing the upload key doesn't
affect users. To move an app onto it, request an upload key reset in Play Console with the
key's certificate:

```sh
keytool -export -rfc -keystore doc-upload-key.keystore -alias doc-key-alias -file doc-upload-key.pem
```

## Building a signed release locally

Add these to `~/.gradle/gradle.properties`, or pass them with `-P`, then run
`./gradlew bundleRelease`. Without them the release build is unsigned.

```properties
UPLOAD_STORE_FILE=/path/to/doc-upload-key.keystore
UPLOAD_STORE_PASSWORD=...
UPLOAD_KEY_ALIAS=doc-key-alias
UPLOAD_KEY_PASSWORD=...
```

## How releases work

Every push to `main` builds and tests the app. Then the deploy job:

1. Raises `versionCode` to Google Play's highest version code if Play is ahead (for example
   after a manual upload).
2. Looks at the commits since the last `x.y.z` tag. If there are `feat:`, `fix:` or `perf:`
   commits, it bumps the version, prepends the release to `CHANGELOG.md` and writes the Play
   release notes.
3. Uploads to the Play **internal** track whenever `versionCode` is newer than Play's.
4. Commits the version (`chore: release x.y.z`) and creates a GitHub prerelease with the
   changelog.

Promote releases to production by hand in Play Console.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/). Pull requests fail
if a commit doesn't follow the format.

| Type | Release | In changelog |
| --- | --- | --- |
| `feat:` | minor (0.4.0 → 0.5.0) | Features |
| `fix:` | patch (0.4.0 → 0.4.1) | Bug fixes |
| `perf:` | patch | Performance |
| `feat!:`, `fix!:` or a `BREAKING CHANGE:` footer | major (0.4.0 → 1.0.0) | Breaking changes |
| `refactor:`, `revert:`, `docs:`, `style:`, `test:`, `build:`, `ci:`, `chore:` | none | no |

Reference the issue in every `feat:`/`fix:`/`perf:` commit, in the subject or body
(e.g. `Fixes #12`). The changelog links it, and pull requests warn when it's missing.

The description is also used, without the issue links, as the Google Play release
notes, so write it for app users: `fix: the tone no longer clicks at the end`,
not `fix: ramp amplitude in genTone()`.

If you squash-merge, the PR title becomes the commit, so it must follow the same rules.

## Code reviewer

`reviewer/android-reviewer.md` is a Claude Code agent for Java and Kotlin Android changes.
The `code-review.yml` workflow runs it on every non-draft pull request and posts a summary
comment, plus inline comments for CRITICAL and HIGH findings. Its instructions always come
from this repo, so a pull request can't change how it is reviewed.

To use it locally, copy it to `~/.claude/agents/android-reviewer.md` and ask Claude Code to
"review this branch with android-reviewer".

## Changing doc-ci

Apps pin a major version tag (`@v1`), so a change here doesn't reach every app at once.

- Backwards-compatible change: merge to `main`, then move the tag:
  `git tag -f v1 && git push -f origin v1`.
- Breaking change: tag `v2`, update the `doc-ci-ref` default in both workflows to `v2`, and
  move each app over by changing `@v1` to `@v2`.
