#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
#
# Builds mkxp-z (RPGPlayer iOS fork, GPL-2.0-or-later) as a static library for iOS.
# Run ThirdParty/mkxp-deps first. Usage: ./build.sh [iphonesimulator|iphoneos]
set -euo pipefail

PLATFORM=${1:-iphonesimulator}
HERE=${0:A:h}
CACHE=$HOME/Library/Caches/RPGMarker
SOURCE=$CACHE/mkxp-z-src
BUILD=$CACHE/mkxp-build-$PLATFORM
DEPS=$CACHE/mkxp-deps/build-$PLATFORM

# The exact upstream revision our patch applies to.
REPO=https://github.com/am1guard/RPGPlayer-MKXP-Z.git
REVISION=2400ad2f6560a00b0e34b2bcc3a3c3f95433dad8

if [[ ! -d $SOURCE ]]; then
    git clone -q $REPO $SOURCE
    git -C $SOURCE checkout -q $REVISION
    git -C $SOURCE apply "$HERE/patches/mkxp-z-ios.patch"
fi

cmake -S "$HERE" -B $BUILD -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=$PLATFORM -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$DEPS -DMKXPZ_ROOT=$SOURCE -DDEPS_DIR=$DEPS
cmake --build $BUILD
cmake --install $BUILD

# One archive for the app to link: mkxp-z, Ruby and every dependency.
# Left out: libSDL2main (defines main, which the app owns) and duplicate variants.
OUT="$HERE/../Build/$PLATFORM"
mkdir -p "$OUT"
LIBS=(mkxpz ruby-static SDL2 SDL2_image SDL2_sound SDL2_ttf openal physfs pixman-1 freetype png16 uchardet
      theora vorbis vorbisfile ogg)
xcrun libtool -static -no_warning_for_no_symbols -o "$OUT/libmkxpz-all.a" $(for l in $LIBS; do print -r -- "$DEPS/lib/lib$l.a"; done)
echo "Wrote $OUT/libmkxpz-all.a"

# mkxp-z's Apple build reads its shaders, fonts and controller database from Assets.bundle in the
# app. Generated here, next to the bridge, where Xcode picks it up (git-ignored).
ASSETS="$HERE/../../RPG Maker/Runtime/MKXP/Assets.bundle"
rm -rf "$ASSETS"
mkdir -p "$ASSETS/Shaders"
cp "$SOURCE"/shader/* "$ASSETS/Shaders/"
cp "$SOURCE"/assets/*.ttf "$SOURCE"/assets/icon.png "$ASSETS/"
[[ -f "$SOURCE/assets/gamecontrollerdb.txt" ]] && cp "$SOURCE/assets/gamecontrollerdb.txt" "$ASSETS/"
echo "Wrote $ASSETS"
