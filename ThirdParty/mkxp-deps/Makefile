# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
#
# Builds mkxp-z's dependencies as static libraries for iOS.
# Adapted from mkxp-z's macos/Dependencies/common.make (GPL-2.0-or-later).
#
#   make everything PLATFORM=iphonesimulator    # arm64 simulator (default)
#   make everything PLATFORM=iphoneos           # arm64 device
#
# Everything happens under ROOT, outside the repository (make can't handle the space in
# "RPG Maker"): ROOT/build-$(PLATFORM)/{lib,include}, sources in ROOT/downloads/$(PLATFORM).

PLATFORM ?= iphonesimulator
ARCH := arm64
MINIMUM_REQUIRED := 17.0

ifeq ($(PLATFORM),iphonesimulator)
TARGET := arm64-apple-ios$(MINIMUM_REQUIRED)-simulator
else
TARGET := arm64-apple-ios$(MINIMUM_REQUIRED)
endif

ROOT ?= $(HOME)/Library/Caches/RPGMarker/mkxp-deps
SDKROOT := $(shell xcrun --sdk $(PLATFORM) --show-sdk-path)
BUILD_PREFIX := $(ROOT)/build-$(PLATFORM)
LIBDIR := $(BUILD_PREFIX)/lib
INCLUDEDIR := $(BUILD_PREFIX)/include
DOWNLOADS := $(ROOT)/downloads/$(PLATFORM)
NPROC := $(shell sysctl -n hw.ncpu)

TARGETFLAGS := -target $(TARGET) -isysroot $(SDKROOT)
CFLAGS := -I$(INCLUDEDIR) -I$(INCLUDEDIR)/freetype2 $(TARGETFLAGS) -O2
LDFLAGS := -L$(LIBDIR) $(TARGETFLAGS)
CC := $(shell xcrun --sdk $(PLATFORM) --find clang)
CXX := $(shell xcrun --sdk $(PLATFORM) --find clang++)
PKG_CONFIG_LIBDIR := $(BUILD_PREFIX)/lib/pkgconfig
CLONE := git clone -q --depth 1
GITHUB := https://github.com

# Autotools: a host triple that differs from the build machine puts configure in
# cross-compiling mode (it can't run iOS binaries on the Mac).
CONFIGURE_ENV := \
	IPHONEOS_DEPLOYMENT_TARGET=$(MINIMUM_REQUIRED) \
	PKG_CONFIG_LIBDIR=$(PKG_CONFIG_LIBDIR) \
	CC="$(CC)" CXX="$(CXX)" CFLAGS="$(CFLAGS)" CXXFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" \
	CPPFLAGS="$(TARGETFLAGS) -I$(INCLUDEDIR)"
CONFIGURE_ARGS := --prefix="$(BUILD_PREFIX)" --host=arm-apple-darwin --enable-static --disable-shared
CMAKE_ARGS := \
	-DCMAKE_SYSTEM_NAME=iOS \
	-DCMAKE_OSX_SYSROOT=$(PLATFORM) \
	-DCMAKE_OSX_ARCHITECTURES=$(ARCH) \
	-DCMAKE_OSX_DEPLOYMENT_TARGET=$(MINIMUM_REQUIRED) \
	-DCMAKE_INSTALL_PREFIX="$(BUILD_PREFIX)" \
	-DCMAKE_PREFIX_PATH="$(BUILD_PREFIX)" \
	-DCMAKE_FIND_ROOT_PATH="$(BUILD_PREFIX)" \
	-DCMAKE_C_FLAGS="-I$(INCLUDEDIR)" \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.10 \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_SHARED_LIBS=OFF
CONFIGURE := $(CONFIGURE_ENV) ./configure $(CONFIGURE_ARGS)
CMAKE := PKG_CONFIG_LIBDIR=$(PKG_CONFIG_LIBDIR) cmake .. $(CMAKE_ARGS)

default: everything

# ---- Ogg / Vorbis / Theora
libogg: init_dirs $(LIBDIR)/libogg.a
$(LIBDIR)/libogg.a: | $(DOWNLOADS)/ogg
	cd $(DOWNLOADS)/ogg && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) && make -j$(NPROC) install
$(DOWNLOADS)/ogg:
	$(CLONE) $(GITHUB)/xiph/ogg -b v1.3.6 $@

libvorbis: init_dirs libogg $(LIBDIR)/libvorbis.a
$(LIBDIR)/libvorbis.a: | $(DOWNLOADS)/vorbis
	cd $(DOWNLOADS)/vorbis && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) && make -j$(NPROC) install
$(DOWNLOADS)/vorbis:
	$(CLONE) $(GITHUB)/xiph/vorbis -b v1.3.7 $@

libtheora: init_dirs libvorbis libogg $(LIBDIR)/libtheora.a
$(LIBDIR)/libtheora.a: | $(DOWNLOADS)/theora
	cd $(DOWNLOADS)/theora && ./autogen.sh >/dev/null && $(CONFIGURE) --with-ogg=$(BUILD_PREFIX) --disable-examples --disable-asm --disable-spec \
		&& make -j$(NPROC) && make install
$(DOWNLOADS)/theora:
	$(CLONE) $(GITHUB)/xiph/theora -b v1.2.0 $@

# ---- Text, images, filesystem
uchardet: init_dirs $(LIBDIR)/libuchardet.a
$(LIBDIR)/libuchardet.a: | $(DOWNLOADS)/uchardet
	cd $(DOWNLOADS)/uchardet && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) -DBUILD_BINARY=OFF && make -j$(NPROC) install
$(DOWNLOADS)/uchardet:
	$(CLONE) https://gitlab.freedesktop.org/uchardet/uchardet.git -b v0.0.8 $@

libpng: init_dirs $(LIBDIR)/libpng.a
$(LIBDIR)/libpng.a: | $(DOWNLOADS)/libpng
	cd $(DOWNLOADS)/libpng && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) -DPNG_SHARED=OFF -DPNG_TESTS=OFF -DPNG_TOOLS=OFF -DPNG_FRAMEWORK=OFF && make -j$(NPROC) install
$(DOWNLOADS)/libpng:
	$(CLONE) $(GITHUB)/pnggroup/libpng -b v1.6.50 $@

pixman: init_dirs $(LIBDIR)/libpixman-1.a
$(LIBDIR)/libpixman-1.a: | $(DOWNLOADS)/pixman
	cd $(DOWNLOADS)/pixman && NOCONFIGURE=1 ./autogen.sh >/dev/null && $(CONFIGURE) --disable-arm-a64-neon --disable-gtk --disable-libpng \
		&& make -C pixman -j$(NPROC) && make -C pixman install && make install-pkgconfigDATA
$(DOWNLOADS)/pixman:
	$(CLONE) https://gitlab.freedesktop.org/pixman/pixman.git -b pixman-0.42.2 $@

physfs: init_dirs $(LIBDIR)/libphysfs.a
$(LIBDIR)/libphysfs.a: | $(DOWNLOADS)/physfs
	cd $(DOWNLOADS)/physfs && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) -DPHYSFS_BUILD_STATIC=ON -DPHYSFS_BUILD_SHARED=OFF -DPHYSFS_BUILD_TEST=OFF -DPHYSFS_BUILD_DOCS=OFF && make -j$(NPROC) install
$(DOWNLOADS)/physfs:
	$(CLONE) $(GITHUB)/icculus/physfs -b release-3.2.0 $@

freetype: init_dirs $(LIBDIR)/libfreetype.a
$(LIBDIR)/libfreetype.a: | $(DOWNLOADS)/freetype
	cd $(DOWNLOADS)/freetype && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON && make -j$(NPROC) install
$(DOWNLOADS)/freetype:
	$(CLONE) $(GITHUB)/mkxp-z/freetype2 $@

# ---- SDL
sdl2: init_dirs $(LIBDIR)/libSDL2.a
$(LIBDIR)/libSDL2.a: | $(DOWNLOADS)/sdl2
	cd $(DOWNLOADS)/sdl2 && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF && make -j$(NPROC) install
$(DOWNLOADS)/sdl2:
	$(CLONE) $(GITHUB)/mkxp-z/SDL -b mkxp-z-2.28.1 $@
	# Create SDL's UIWindow in the app's window scene, or SwiftUI apps never show it.
	git -C $@ apply "$(CURDIR)/patches/sdl2-ios-window-scene.patch"

sdl2image: init_dirs sdl2 libpng $(LIBDIR)/libSDL2_image.a
$(LIBDIR)/libSDL2_image.a: | $(DOWNLOADS)/sdl2_image
	cd $(DOWNLOADS)/sdl2_image && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) \
		-DSDL2IMAGE_SAMPLES=OFF -DSDL2IMAGE_TESTS=OFF -DSDL2IMAGE_DEPS_SHARED=OFF -DSDL2IMAGE_VENDORED=ON \
		-DSDL2IMAGE_JPG_SAVE=ON -DSDL2IMAGE_PNG_SAVE=ON -DSDL2IMAGE_JXL=OFF -DSDL2IMAGE_AVIF=OFF -DSDL2IMAGE_WEBP=OFF \
		-DSDL2IMAGE_TIF=OFF -DSDL2IMAGE_BACKEND_IMAGEIO=OFF && make -j$(NPROC) install
$(DOWNLOADS)/sdl2_image:
	$(CLONE) $(GITHUB)/mkxp-z/SDL_image -b mkxp-z $@ && cd $@ && ./external/download.sh

sdlsound: init_dirs sdl2 libogg libvorbis $(LIBDIR)/libSDL2_sound.a
$(LIBDIR)/libSDL2_sound.a: | $(DOWNLOADS)/sdl_sound
	cd $(DOWNLOADS)/sdl_sound && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) \
		-DSDLSOUND_BUILD_SHARED=OFF -DSDLSOUND_BUILD_TEST=OFF -DSDLSOUND_DECODER_COREAUDIO=OFF && make -j$(NPROC) install
$(DOWNLOADS)/sdl_sound:
	$(CLONE) $(GITHUB)/mkxp-z/SDL_sound -b git $@

sdl2ttf: init_dirs sdl2 freetype $(LIBDIR)/libSDL2_ttf.a
$(LIBDIR)/libSDL2_ttf.a: | $(DOWNLOADS)/sdl2_ttf
	cd $(DOWNLOADS)/sdl2_ttf && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) \
		-DSDL2TTF_SAMPLES=OFF -DSDL2TTF_VENDORED=OFF -DSDL2TTF_HARFBUZZ=OFF && make -j$(NPROC) install
$(DOWNLOADS)/sdl2_ttf:
	$(CLONE) $(GITHUB)/mkxp-z/SDL_ttf -b mkxp-z $@

# ---- Audio output
openal: init_dirs $(LIBDIR)/libopenal.a
$(LIBDIR)/libopenal.a: | $(DOWNLOADS)/openal
	cd $(DOWNLOADS)/openal && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) \
		-DLIBTYPE=STATIC -DALSOFT_EXAMPLES=OFF -DALSOFT_UTILS=OFF -DALSOFT_TESTS=OFF -DALSOFT_INSTALL_EXAMPLES=OFF \
		-DALSOFT_BACKEND_WAVE=OFF && make -j$(NPROC) install
$(DOWNLOADS)/openal:
	$(CLONE) $(GITHUB)/kcat/openal-soft -b 1.24.3 $@

# ---- MIDI: FluidSynth, synthesizer only (mkxp-z renders it into OpenAL). No GLib: osal=cpp11.
FLUIDSYNTH_OFF := alsa aufile dbus ipv6 jack ladspa libsndfile midishare network oss sdl3 pulseaudio \
	pipewire readline openmp systemd coreaudio coremidi framework native-dls
fluidsynth: init_dirs $(LIBDIR)/libfluidsynth.a
$(LIBDIR)/libfluidsynth.a: | $(DOWNLOADS)/fluidsynth
	cd $(DOWNLOADS)/fluidsynth && mkdir -p cmakebuild && cd cmakebuild && $(CMAKE) -Dosal=cpp11 -DCMAKE_MACOSX_BUNDLE=OFF \
		$(foreach option,$(FLUIDSYNTH_OFF),-Denable-$(option)=off) && make -j$(NPROC) install
$(DOWNLOADS)/fluidsynth:
	$(CLONE) --recurse-submodules --shallow-submodules $(GITHUB)/FluidSynth/fluidsynth -b v2.6.1 $@

# ---- Ruby (mkxp-z's 3.1 branch), static, extensions linked in, no JIT (not allowed on iOS).
# Cross-compiling needs a Ruby on the Mac to run the build scripts (BASERUBY).
# CC carries the target flags too: Ruby's assembly (coroutine/arm64/Context.S) doesn't get CFLAGS.
BASERUBY ?= $(shell command -v ruby)
# Answers configure can't find out when cross-compiling, or gets wrong for iOS.
RUBY_CACHE := ac_cv_func_getentropy=no ac_cv_func_dup3=no ac_cv_func_pipe2=no ac_cv_func_accept4=no \
	ac_cv_func_getrandom=no ac_cv_func_memfd_create=no ac_cv_func_copy_file_range=no ac_cv_func_close_range=no
RUBY_EXCLUDED_EXTS := bigdecimal,debug,fiddle,gdbm,win32ole,win32,openssl,readline,pty,dbm,nkf,syslog,etc,objspace,-test-

ruby: init_dirs $(LIBDIR)/libruby-static.a
$(LIBDIR)/libruby-static.a: | $(DOWNLOADS)/ruby
	cd $(DOWNLOADS)/ruby && ( [ -f configure ] || autoreconf -i >/dev/null ) && \
	$(CONFIGURE_ENV) CFLAGS="-std=gnu99 -DRUBY_FUNCTION_NAME_STRING=__func__ $(CFLAGS)" CC="$(CC) $(TARGETFLAGS)" \
	$(RUBY_CACHE) ./configure --prefix="$(BUILD_PREFIX)" --host=arm-apple-darwin --build=aarch64-apple-darwin \
		--disable-shared --enable-install-static-library --with-static-linked-ext \
		--disable-rubygems --disable-install-doc --disable-jit-support --disable-dtrace \
		--with-baseruby=$(BASERUBY) --with-out-ext=$(RUBY_EXCLUDED_EXTS) && \
	make -j$(NPROC) && make install-nodoc && \
	xcrun libtool -static -no_warning_for_no_symbols -o $@ $(LIBDIR)/libruby.3.1-static.a \
		ext/extinit.o enc/libenc.a enc/libtrans.a $$(find ext -name '*.a')
	# ↑ One archive with the interpreter, its statically linked extensions and encodings.
$(DOWNLOADS)/ruby:
	$(CLONE) $(GITHUB)/mkxp-z/ruby -b mkxp-z-3.1.3 $@
	# iOS fixes: skip the macOS-only version check, no sys/vnode.h, no -bundle_loader, no bundled gems.
	git -C $@ apply "$(CURDIR)/patches/ruby-3.1-ios.patch"

init_dirs:
	@mkdir -p $(LIBDIR) $(INCLUDEDIR)

clean:
	rm -rf $(BUILD_PREFIX)

deps-core: libogg libvorbis libtheora uchardet libpng pixman physfs freetype sdl2 sdl2image sdlsound sdl2ttf openal fluidsynth
everything: deps-core ruby

.PHONY: default init_dirs clean deps-core everything ruby fluidsynth libogg libvorbis libtheora uchardet libpng pixman physfs freetype sdl2 sdl2image sdlsound sdl2ttf openal
