#!/bin/bash
# Builds the XP/VX/VX Ace runtime (mkxp-z and its dependencies) for a platform, unless an up-to-date
# build is available. "Up to date" means built from the same ThirdParty/ scripts and patches.
#
#   scripts/ci_build_mkxp.sh [iphoneos|iphonesimulator]
#
# Uses, in order: the committed build in ThirdParty/Prebuilt (scripts/update_prebuilt_mkxp.sh), the
# MKXP_CACHE folder (CI build cache, restored from / saved to), or a fresh build.
# `--inputs` prints the fingerprint of the ThirdParty/ sources the build depends on.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fingerprint() {
    # git ls-files lists in byte order and shasum prints relative paths, so the result is the same on
    # every machine (no locale-dependent sort).
    (cd "$ROOT/ThirdParty" && LC_ALL=C git ls-files mkxp-deps mkxp-ios SOURCES.md | LC_ALL=C xargs shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
}
if [ "${1:-}" = "--inputs" ]; then fingerprint; exit 0; fi

PLATFORM="${1:-iphoneos}"
OUT="$ROOT/ThirdParty/Build/$PLATFORM"
ASSETS="$ROOT/RPG Maker/Runtime/MKXP/Assets.bundle"
CACHE="${MKXP_CACHE:-}"

INPUTS=$(fingerprint)
echo "ThirdParty fingerprint: $INPUTS"

is_current() {  # <folder with libmkxpz-all.a, Assets.bundle and .inputs>
    [ -f "$1/libmkxpz-all.a" ] && [ -d "$1/Assets.bundle/Shaders" ] && [ "$(cat "$1/.inputs" 2>/dev/null)" = "$INPUTS" ]
}

use() {  # <folder>
    mkdir -p "$OUT"
    cp "$1/libmkxpz-all.a" "$OUT/"
    rm -rf "$ASSETS" && cp -R "$1/Assets.bundle" "$ASSETS"
}

if is_current "$ROOT/ThirdParty/Prebuilt/$PLATFORM"; then
    echo "Using the committed mkxp-z build for $PLATFORM (ThirdParty/Prebuilt)."
    use "$ROOT/ThirdParty/Prebuilt/$PLATFORM"
    exit 0
fi
if [ -n "$CACHE" ] && is_current "$CACHE/$PLATFORM"; then
    echo "Using the cached mkxp-z build for $PLATFORM."
    use "$CACHE/$PLATFORM"
    exit 0
fi
echo "ThirdParty/Prebuilt/$PLATFORM is missing or older than ThirdParty/; building from source."

echo "Building mkxp-z for $PLATFORM (about 40 minutes)…"
brew list cmake meson ninja autoconf automake libtool pkg-config >/dev/null 2>&1 \
    || brew install cmake meson ninja autoconf automake libtool pkg-config
# Sequential on purpose: the targets build in order (SDL before SDL_image, …) and each one already
# compiles in parallel. With -j here, SDL_image configures before SDL is installed.
make -C "$ROOT/ThirdParty/mkxp-deps" everything PLATFORM="$PLATFORM"
# Where Ruby put its headers and library (mkxp-z's build needs both).
DEPS="$HOME/Library/Caches/RPGMarker/mkxp-deps/build-$PLATFORM"
echo "Ruby files in $DEPS:"
find "$DEPS/include" "$DEPS/lib" -maxdepth 3 \( -name ruby.h -o -name config.h -path "*darwin*" -o -name "libruby*" \) -print || true
if ! find "$DEPS/include" -name ruby.h -print -quit | grep -q .; then
    echo "ruby.h is missing: the Ruby build above didn't install its headers." >&2
    exit 1
fi
"$ROOT/ThirdParty/mkxp-ios/build.sh" "$PLATFORM"

if [ -n "$CACHE" ]; then
    rm -rf "$CACHE/$PLATFORM" && mkdir -p "$CACHE/$PLATFORM"
    cp "$OUT/libmkxpz-all.a" "$CACHE/$PLATFORM/"
    cp -R "$ASSETS" "$CACHE/$PLATFORM/Assets.bundle"
    echo "$INPUTS" > "$CACHE/$PLATFORM/.inputs"
    echo "Saved the build to $CACHE/$PLATFORM"
fi
