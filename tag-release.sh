#!/bin/bash
# Creates the release tag, after checking the things that went wrong last time.
#
# Run this from main, with everything committed, immediately before publishing.
# It does local work only. It never pushes and never publishes.
#
# Why each check exists:
#
#   ancestor    v0.1 was tagged on a commit that history rewriting later
#               replaced, so the tag ended up on a parallel line and
#               `git log v0.1..main` listed the entire project. A report built
#               on that range was wrong by 34 commits.
#   annotated   v0.1 was lightweight, which is part of why the drift was
#               invisible. Annotated tags carry a date, an author and a message.
#   dated       the 0.1 changelog heading said "unreleased" for three weeks
#               after 0.1 shipped, so a later entry landed inside a version
#               that was already out.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(sed -n 's/.*CFBundleShortVersionString<\/key><string>\(.*\)<\/string>.*/\1/p' build.sh)
[ -n "$VERSION" ] || { echo "error: cannot read the version from build.sh" >&2; exit 1; }
TAG="v$VERSION"

fail() { echo "error: $1" >&2; exit 1; }

[ -z "$(git status --porcelain)" ] || fail "the working tree is not clean."

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] || fail "you are on '$BRANCH', not main."

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && \
  fail "$TAG already exists. Moving a published tag can draft its GitHub release."

grep -q "^## $VERSION — unreleased" CHANGELOG.md && \
  fail "the CHANGELOG heading for $VERSION still says 'unreleased'. Date it first."

grep -q "^## $VERSION — [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" CHANGELOG.md || \
  fail "no dated '## $VERSION — YYYY-MM-DD' heading found in CHANGELOG.md."

git tag -a "$TAG" -m "unstray $VERSION"

git merge-base --is-ancestor "$TAG" main || {
  git tag -d "$TAG"
  fail "$TAG is not an ancestor of main. Tag removed. This is the v0.1 failure."
}

DESCRIBED=$(git describe --tags main)
[ "$DESCRIBED" = "$TAG" ] || { git tag -d "$TAG"; fail "git describe returned '$DESCRIBED'. Tag removed."; }

echo "tagged: $TAG on $(git rev-parse --short HEAD)"
echo "git describe agrees: $DESCRIBED"
echo
echo "Nothing has been pushed. Next, in order:"
echo "  1. ./build.sh --notarize"
echo "  2. xcrun stapler validate on the EXTRACTED zip, not the build directory"
echo "  3. git push origin main --follow-tags"
echo "  4. upload the zip to a new GitHub release for $TAG"
