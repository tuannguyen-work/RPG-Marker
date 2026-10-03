#!/bin/bash
# Builds the XP/VX/VX Ace runtime (mkxp-z and its dependencies) for a platform, unless an up-to-date
# build is available. "Up to date" means built from the same ThirdParty/ scripts and patches.
#
#   scripts/ci_build_mkxp.sh [iphoneos|iphonesimulator]
#
# With MKXP_CACHE set (CI), the outputs are kept in that folder: restored from it when current,
# saved to it after a build. Its path has no spaces, unlike the repository's.
set -euo pipefail

PLATFORM="${1:-iphoneos}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/ThirdParty/Build/$PLATFORM"
ASSETS="$ROOT/RPG Maker/Runtime/MKXP/Assets.bundle"
CACHE="${MKXP_CACHE:-}"

INPUTS=$(cd "$ROOT/ThirdParty" && git ls-files mkxp-deps mkxp-ios SOURCES.md | sort | xargs shasum -a 256 | shasum -a 256 | cut -d' ' -f1)

is_current() {  # <folder with libmkxpz-all.a, Assets.bundle and .inputs>
    [ -f "$1/libmkxpz-all.a" ] && [ -d "$1/Assets.bundle/Shaders" ] && [ "$(cat "$1/.inputs" 2>/dev/null)" = "$INPUTS" ]
}

if [ -n "$CACHE" ] && is_current "$CACHE/$PLATFORM"; then
    echo "Using the cached mkxp-z build for $PLATFORM."
    mkdir -p "$OUT"
    cp "$CACHE/$PLATFORM/libmkxpz-all.a" "$OUT/"
    rm -rf "$ASSETS" && cp -R "$CACHE/$PLATFORM/Assets.bundle" "$ASSETS"
    exit 0
fi

echo "Building mkxp-z for $PLATFORM (about 40 minutes)…"
brew list cmake meson ninja autoconf automake libtool pkg-config >/dev/null 2>&1 \
    || brew install cmake meson ninja autoconf automake libtool pkg-config
# Sequential on purpose: the targets build in order (SDL before SDL_image, …) and each one already
# compiles in parallel. With -j here, SDL_image configures before SDL is installed.
make -C "$ROOT/ThirdParty/mkxp-deps" everything PLATFORM="$PLATFORM"
"$ROOT/ThirdParty/mkxp-ios/build.sh" "$PLATFORM"

if [ -n "$CACHE" ]; then
    rm -rf "$CACHE/$PLATFORM" && mkdir -p "$CACHE/$PLATFORM"
    cp "$OUT/libmkxpz-all.a" "$CACHE/$PLATFORM/"
    cp -R "$ASSETS" "$CACHE/$PLATFORM/Assets.bundle"
    echo "$INPUTS" > "$CACHE/$PLATFORM/.inputs"
    echo "Saved the build to $CACHE/$PLATFORM"
fi
