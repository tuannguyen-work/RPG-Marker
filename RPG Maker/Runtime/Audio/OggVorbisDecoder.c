//
//  OggVorbisDecoder.c
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//
//  Compiles the vendored stb_vorbis (v1.22, MIT / public domain, see THIRD_PARTY_NOTICES.md).
//  The library is kept unmodified in stb_vorbis_impl.h; its warnings are not ours to fix.
//

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
#include "stb_vorbis_impl.h"
#pragma clang diagnostic pop
