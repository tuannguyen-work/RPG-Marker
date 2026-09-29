#!/bin/bash
# Captures App Store screenshots on the iPhone 17 Pro Max simulator (6.9", 1320x2868) using the
# app's DEBUG launch arguments (sample library, open detail/guide/settings) and a clean status bar.
# Output: fastlane/screenshots/en-US/<n>_<name>.png, ready for `fastlane upload_screenshots`.
#
# A screenshot of a game being played can't be automated without shipping a game. Take it by hand
# on the same simulator (landscape, Cmd+S) and save it into the same folder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/fastlane/screenshots/en-US"
DERIVED="$ROOT/fastlane/build/ScreenshotsDerivedData"
DEVICE_NAME="iPhone 17 Pro Max"
BUNDLE_ID="com.solid.questplayer"

UDID=$(xcrun simctl list devices available | grep -m1 "$DEVICE_NAME (" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "No '$DEVICE_NAME' simulator found"; exit 1; }

echo "Building for $DEVICE_NAME ($UDID)…"
xcodebuild -project "$ROOT/RPG Maker.xcodeproj" -scheme "RPG Maker" -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" build -quiet
APP=$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "*.app" | head -1)

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

mkdir -p "$OUT"
rm -f "$OUT"/*_auto_*.png

# name, then launch arguments
shoot() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@" >/dev/null
  sleep 5   # let sheets and animations settle
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "  $name"
}

echo "Capturing…"
shoot 1_auto_library   -sampleData -hasCompletedOnboarding YES
shoot 2_auto_details   -sampleData -hasCompletedOnboarding YES -showDetail
shoot 3_auto_guide     -sampleData -hasCompletedOnboarding YES -showGuide importing
shoot 4_auto_controls  -sampleData -hasCompletedOnboarding YES -showGuide controls
shoot 5_auto_settings  -sampleData -hasCompletedOnboarding YES -showSettings
shoot 6_auto_welcome   -sampleData -hasCompletedOnboarding NO

xcrun simctl status_bar "$UDID" clear
echo "Saved to $OUT"
