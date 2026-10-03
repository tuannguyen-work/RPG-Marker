#!/bin/bash
# Points every public link (app Settings, privacy policy, App Store metadata) at the public source
# repository:  scripts/set_public_repo.sh https://github.com/<owner>/<repo>
set -euo pipefail

NEW="${1:?usage: scripts/set_public_repo.sh https://github.com/<owner>/<repo>}"
NEW="${NEW%.git}"; NEW="${NEW%/}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OLD=$(grep -oE 'https://github.com/[^/"]+/[^/"]+' "RPG Maker/Features/Settings/SettingsView.swift" | head -1)
FILES=(
    "RPG Maker/Features/Settings/SettingsView.swift"
    "PRIVACY.md"
    "fastlane/metadata/en-US/privacy_url.txt"
    "fastlane/metadata/en-US/support_url.txt"
    "fastlane/metadata/en-US/marketing_url.txt"
)
for file in "${FILES[@]}"; do
    sed -i '' "s#$OLD#$NEW#g" "$file"
done
echo "Links changed from $OLD to $NEW:"
grep -n "$NEW" "${FILES[@]}"
