//
//  OggVorbisDecoder.h
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

#ifndef OggVorbisDecoder_h
#define OggVorbisDecoder_h

/// From stb_vorbis (prefixed qp_, see OggVorbisDecoder.c): decodes a whole Ogg Vorbis file in
/// memory to interleaved 16-bit PCM.
/// Returns the number of frames (samples per channel), or a negative value on error.
/// `*output` is allocated with malloc; release it with free().
int qp_stb_vorbis_decode_memory(const unsigned char *mem, int len, int *channels, int *sample_rate, short **output);

#endif
