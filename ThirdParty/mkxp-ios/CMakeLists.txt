# SPDX-License-Identifier: GPL-3.0-or-later
# Adapted from the RPGPlayer mkxp-z fork's ios/CMakeLists.txt (GPL-2.0-or-later).
# MKXP-Z iOS Build Configuration
# CMakeLists.txt for cross-compiling MKXP-Z engine for iOS
# Use with: cmake -DCMAKE_TOOLCHAIN_FILE=../../deps/ios_toolchain.cmake -G Xcode ..
cmake_minimum_required(VERSION 3.20)

project(mkxp-z-ios VERSION 2.4.2 LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ====================
# Configuration
# ====================

# mkxp-z sources and the dependency prefix built by ThirdParty/mkxp-deps/Makefile
set(MKXPZ_ROOT "${MKXPZ_ROOT}" CACHE PATH "mkxp-z source tree (RPGPlayer iOS fork)")
set(DEPS_DIR "${DEPS_DIR}" CACHE PATH "Dependency prefix, e.g. ~/Library/Caches/RPGMarker/mkxp-deps/build-iphonesimulator")

# Platform detection for device vs simulator
if(CMAKE_OSX_SYSROOT MATCHES "iphonesimulator")
    set(IOS_PLATFORM "SIMULATOR")
    set(RUBY_LIB_DIR "${DEPS_DIR}/lib/simulator")
else()
    set(IOS_PLATFORM "DEVICE")
    set(RUBY_LIB_DIR "${DEPS_DIR}/lib/device")
endif()

message(STATUS "MKXP-Z iOS Build")
message(STATUS "  Platform: ${IOS_PLATFORM}")
message(STATUS "  Dependencies: ${DEPS_DIR}")

# ====================
# Build Definitions
# ====================

add_compile_definitions(
    MKXPZ_VERSION="${PROJECT_VERSION}"
    MKXPZ_BUILD_CMAKE
    MKXPZ_BUILD_XCODE  # Enables Apple platform-specific code
    MKXPZ_ALCDEVICE=ALCdevice
    AL_LIBTYPE_STATIC
    GLES2_HEADER
    HAVE_NANOSLEEP
    IOS_PLATFORM
    MKXPZ_MINIFFI  # Enable Win32API module
    MKXPZ_NO_SYSTEM_CALL  # Disable std::system() calls on iOS
)

# ====================
# Include Directories
# ====================

set(MKXPZ_SRC_DIR "${MKXPZ_ROOT}/src")
set(MKXPZ_BINDING_DIR "${MKXPZ_ROOT}/binding")
set(MKXPZ_SHADER_DIR "${MKXPZ_ROOT}/shader")
set(MKXPZ_ASSETS_DIR "${MKXPZ_ROOT}/assets")

# Shaders and bundled assets are compiled in as C arrays (xxd -i), named as mkxp-z expects:
# ___shader_<file>_<ext>, ___assets_<file>_<ext>.
set(GENERATED_DIR "${CMAKE_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${GENERATED_DIR}")
file(GLOB EMBEDDED_FILES "${MKXPZ_ROOT}/shader/*" "${MKXPZ_ROOT}/assets/*.ttf")
foreach(EMBEDDED ${EMBEDDED_FILES})
    get_filename_component(NAME "${EMBEDDED}" NAME)
    get_filename_component(FOLDER "${EMBEDDED}" DIRECTORY)
    get_filename_component(FOLDER "${FOLDER}" NAME)
    execute_process(
        COMMAND xxd -i "../${FOLDER}/${NAME}"
        WORKING_DIRECTORY "${MKXPZ_ROOT}/ios"
        OUTPUT_FILE "${GENERATED_DIR}/${NAME}.xxd"
        COMMAND_ERROR_IS_FATAL ANY)
endforeach()

include_directories(
    ${GENERATED_DIR}
    ${MKXPZ_ROOT}/ios  # iOS-specific stubs (TouchBar.h)
    ${MKXPZ_ROOT}/ios/generated  # Generated xxd headers
    ${MKXPZ_ROOT}  # For 'src/util/util.h' style includes
    ${MKXPZ_SRC_DIR}
    ${MKXPZ_SRC_DIR}/audio
    ${MKXPZ_SRC_DIR}/crypto
    ${MKXPZ_SRC_DIR}/display
    ${MKXPZ_SRC_DIR}/display/gl
    ${MKXPZ_SRC_DIR}/display/libnsgif
    ${MKXPZ_SRC_DIR}/display/libnsgif/utils
    ${MKXPZ_SRC_DIR}/etc
    ${MKXPZ_SRC_DIR}/filesystem
    ${MKXPZ_SRC_DIR}/filesystem/ghc
    ${MKXPZ_SRC_DIR}/input
    ${MKXPZ_SRC_DIR}/net
    ${MKXPZ_SRC_DIR}/system
    ${MKXPZ_SRC_DIR}/util
    ${MKXPZ_SRC_DIR}/util/sigslot
    ${MKXPZ_SRC_DIR}/util/sigslot/adapter
    ${MKXPZ_SRC_DIR}/theoraplay
    ${MKXPZ_BINDING_DIR}
    # Dependencies
    ${DEPS_DIR}/include
    ${DEPS_DIR}/include/AL   # OpenAL headers
    ${DEPS_DIR}/include/SDL2
    ${DEPS_DIR}/include/pixman-1  # pixman.h
    ${DEPS_DIR}/include/freetype2  # ft2build.h
    ${DEPS_DIR}/include/uchardet
    ${DEPS_DIR}/include/ruby-3.1.0
    ${DEPS_DIR}/include/ruby-3.1.0/arm64-darwin
)

# ====================
# Source Files
# ====================

set(MKXPZ_SOURCES
    # Core
    ${MKXPZ_SRC_DIR}/main.cpp
    ${MKXPZ_SRC_DIR}/config.cpp
    ${MKXPZ_SRC_DIR}/eventthread.cpp
    ${MKXPZ_SRC_DIR}/settingsmenu.cpp
    ${MKXPZ_SRC_DIR}/sharedstate.cpp
    
    # Audio
    ${MKXPZ_SRC_DIR}/audio/alstream.cpp
    ${MKXPZ_SRC_DIR}/audio/audio.cpp
    ${MKXPZ_SRC_DIR}/audio/audiostream.cpp
    ${MKXPZ_SRC_DIR}/audio/fluid-fun.cpp
    ${MKXPZ_SRC_DIR}/audio/midisource.cpp
    ${MKXPZ_SRC_DIR}/audio/sdlsoundsource.cpp
    ${MKXPZ_SRC_DIR}/audio/soundemitter.cpp
    ${MKXPZ_SRC_DIR}/audio/vorbissource.cpp
    ${MKXPZ_SRC_DIR}/theoraplay/theoraplay.c
    
    # Crypto
    ${MKXPZ_SRC_DIR}/crypto/rgssad.cpp
    
    # Display
    ${MKXPZ_SRC_DIR}/display/autotiles.cpp
    ${MKXPZ_SRC_DIR}/display/autotilesvx.cpp
    ${MKXPZ_SRC_DIR}/display/bitmap.cpp
    ${MKXPZ_SRC_DIR}/display/font.cpp
    ${MKXPZ_SRC_DIR}/display/graphics.cpp
    ${MKXPZ_SRC_DIR}/display/plane.cpp
    ${MKXPZ_SRC_DIR}/display/sprite.cpp
    ${MKXPZ_SRC_DIR}/display/tilemap.cpp
    ${MKXPZ_SRC_DIR}/display/tilemapvx.cpp
    ${MKXPZ_SRC_DIR}/display/viewport.cpp
    ${MKXPZ_SRC_DIR}/display/window.cpp
    ${MKXPZ_SRC_DIR}/display/windowvx.cpp
    ${MKXPZ_SRC_DIR}/display/libnsgif/libnsgif.c
    ${MKXPZ_SRC_DIR}/display/libnsgif/lzw.c
    
    # OpenGL
    ${MKXPZ_SRC_DIR}/display/gl/gl-debug.cpp
    ${MKXPZ_SRC_DIR}/display/gl/gl-fun.cpp
    ${MKXPZ_SRC_DIR}/display/gl/gl-meta.cpp
    ${MKXPZ_SRC_DIR}/display/gl/glstate.cpp
    ${MKXPZ_SRC_DIR}/display/gl/scene.cpp
    ${MKXPZ_SRC_DIR}/display/gl/shader.cpp
    ${MKXPZ_SRC_DIR}/display/gl/texpool.cpp
    ${MKXPZ_SRC_DIR}/display/gl/tileatlas.cpp
    ${MKXPZ_SRC_DIR}/display/gl/tileatlasvx.cpp
    ${MKXPZ_SRC_DIR}/display/gl/tilequad.cpp
    ${MKXPZ_SRC_DIR}/display/gl/vertex.cpp
    
    # Utilities
    ${MKXPZ_SRC_DIR}/util/iniconfig.cpp
    ${MKXPZ_SRC_DIR}/util/win-consoleutils.cpp
    
    # Etc
    ${MKXPZ_SRC_DIR}/etc/etc.cpp
    ${MKXPZ_SRC_DIR}/etc/table.cpp
    
    # Filesystem
    ${MKXPZ_SRC_DIR}/filesystem/filesystem.cpp
    ${MKXPZ_SRC_DIR}/filesystem/filesystemImpl.cpp
    ${MKXPZ_ROOT}/ios/filesystemImplApple-ios.mm  # iOS-specific Apple implementation
    
    # Input
    ${MKXPZ_SRC_DIR}/input/input.cpp
    ${MKXPZ_SRC_DIR}/input/keybindings.cpp
    
    # Network
    ${MKXPZ_SRC_DIR}/net/LUrlParser.cpp
    ${MKXPZ_SRC_DIR}/net/net.cpp
    
    # System (use iOS-specific version)
    ${MKXPZ_SRC_DIR}/system/systemImpl.cpp
    ${MKXPZ_ROOT}/ios/systemImplApple.mm  # iOS-compatible version
    
    # Ruby Bindings (use iOS-patched version for binding-mri)
    ${MKXPZ_ROOT}/ios/binding-mri-ios.cpp  # Patched for iOS std::system unavailability
    ${MKXPZ_BINDING_DIR}/binding-util.cpp
    ${MKXPZ_BINDING_DIR}/table-binding.cpp
    ${MKXPZ_BINDING_DIR}/etc-binding.cpp
    ${MKXPZ_BINDING_DIR}/bitmap-binding.cpp
    ${MKXPZ_BINDING_DIR}/font-binding.cpp
    ${MKXPZ_BINDING_DIR}/graphics-binding.cpp
    ${MKXPZ_BINDING_DIR}/input-binding.cpp
    ${MKXPZ_BINDING_DIR}/sprite-binding.cpp
    ${MKXPZ_BINDING_DIR}/viewport-binding.cpp
    ${MKXPZ_BINDING_DIR}/plane-binding.cpp
    ${MKXPZ_BINDING_DIR}/window-binding.cpp
    ${MKXPZ_BINDING_DIR}/tilemap-binding.cpp
    ${MKXPZ_BINDING_DIR}/audio-binding.cpp
    ${MKXPZ_BINDING_DIR}/module_rpg.cpp
    ${MKXPZ_BINDING_DIR}/filesystem-binding.cpp
    ${MKXPZ_BINDING_DIR}/windowvx-binding.cpp
    ${MKXPZ_BINDING_DIR}/tilemapvx-binding.cpp
    ${MKXPZ_BINDING_DIR}/http-binding.cpp
    ${MKXPZ_BINDING_DIR}/miniffi-binding.cpp
    ${MKXPZ_BINDING_DIR}/miniffi.cpp
)

# ====================
# Static library (linked into the app together with the dependency archives)
# ====================

add_library(mkxpz STATIC ${MKXPZ_SOURCES})
target_compile_options(mkxpz PRIVATE
    -Wno-non-virtual-dtor -Wno-reorder -Wno-uninitialized -Wno-unknown-pragmas
    -Wno-deprecated-declarations -Wno-incompatible-pointer-types -Wno-pointer-sign
    -Wno-incompatible-pointer-types-discards-qualifiers -fdeclspec
    # The fork's Objective-C++ files are written for ARC.
    $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>)
# Ruby's headers turn memcpy into a macro, which breaks <locale> when it's included after them.
set_source_files_properties(${MKXPZ_BINDING_DIR}/miniffi-binding.cpp PROPERTIES COMPILE_OPTIONS "-include;ostream")
install(TARGETS mkxpz ARCHIVE DESTINATION lib)
