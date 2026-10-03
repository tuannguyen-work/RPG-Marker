#!/bin/bash
# Exports the committed tree (HEAD) as a fresh repository without this repo's history, for the
# public source repository. Ignored files (fastlane/.env, App Review contact details, build output)
# are never part of HEAD, so they can't leak; the scan below double-checks before anything is pushed.
#
#   scripts/export_public.sh <destination> [remote-url]
#
# With a remote URL the export is committed and pushed to its main branch (force, since the public
# repository mirrors releases rather than this repository's history).
set -euo pipefail

DEST="${1:?usage: scripts/export_public.sh <destination> [remote-url]}"
REMOTE="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(grep -m1 "MARKETING_VERSION" "$ROOT/RPG Maker.xcodeproj/project.pbxproj" | sed -E 's/.*= ([^;]+);/\1/')
REVISION=$(git -C "$ROOT" rev-parse --short HEAD)

if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
    echo "Commit or stash your changes first; only committed files are exported." >&2
    exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
git -C "$ROOT" archive HEAD | tar -x -C "$DEST"

# Things that must never be public.
echo "Scanning for secrets…"
if grep -rIlE "BEGIN (EC |RSA )?PRIVATE KEY|ASC_(KEY_ID|ISSUER_ID)=[A-Za-z0-9]|AuthKey_[A-Z0-9]{10}\.p8" "$DEST" \
    | grep -v "fastlane/.env.example"; then
    echo "Possible credentials found in the files above. Nothing was pushed." >&2
    exit 1
fi
for f in first_name last_name phone_number email_address; do
    if [ -e "$DEST/fastlane/metadata/review_information/$f.txt" ]; then
        echo "App Review contact detail $f.txt is in the export. Nothing was pushed." >&2
        exit 1
    fi
done

cd "$DEST"
git init -q -b main
git add -A
git commit -q -m "RPG Deck $VERSION source (from $REVISION)"
echo "Exported $(git ls-files | wc -l | tr -d ' ') files to $DEST"

if [ -n "$REMOTE" ]; then
    git remote add origin "$REMOTE"
    git push -f origin main
    git tag "v$VERSION" && git push -f origin "v$VERSION"
    echo "Pushed to $REMOTE (main and v$VERSION)"
fi
