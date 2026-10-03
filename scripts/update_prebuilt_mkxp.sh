#!/bin/bash
# Copies the local device build of the XP/VX/VX Ace runtime into ThirdParty/Prebuilt, so CI can build
# the app without compiling mkxp-z (about 40 minutes). Run after changing ThirdParty/ and rebuilding:
#
#   scripts/ci_build_mkxp.sh iphoneos && scripts/update_prebuilt_mkxp.sh
#
# The sources of these binaries are this repository plus ThirdParty/SOURCES.md (GPL source offer).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM=iphoneos
OUT="$ROOT/ThirdParty/Build/$PLATFORM"
ASSETS="$ROOT/RPG Maker/Runtime/MKXP/Assets.bundle"
PREBUILT="$ROOT/ThirdParty/Prebuilt/$PLATFORM"

[ -f "$OUT/libmkxpz-all.a" ] && [ -d "$ASSETS/Shaders" ] || { echo "Build it first: scripts/ci_build_mkxp.sh $PLATFORM" >&2; exit 1; }

INPUTS=$("$ROOT/scripts/ci_build_mkxp.sh" --inputs)
rm -rf "$PREBUILT" && mkdir -p "$PREBUILT"
cp "$OUT/libmkxpz-all.a" "$PREBUILT/"
cp -R "$ASSETS" "$PREBUILT/Assets.bundle"
echo "$INPUTS" > "$PREBUILT/.inputs"
du -sh "$PREBUILT"
