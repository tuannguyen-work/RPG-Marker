//
//  OggVorbisDecoder.c
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//
//  Compiles the vendored stb_vorbis (v1.22, MIT / public domain, see THIRD_PARTY_NOTICES.md).
//  The library is kept unmodified in stb_vorbis_impl.h; its warnings are not ours to fix.
//

// SDL_sound (linked in with mkxp-z) contains its own copy of stb_vorbis with the same public
// names; prefix ours so the two never collide at link time.
#define stb_vorbis_close qp_stb_vorbis_close
#define stb_vorbis_comment qp_stb_vorbis_comment
#define stb_vorbis_decode_filename qp_stb_vorbis_decode_filename
#define stb_vorbis_decode_frame_pushdata qp_stb_vorbis_decode_frame_pushdata
#define stb_vorbis_decode_memory qp_stb_vorbis_decode_memory
#define stb_vorbis_flush_pushdata qp_stb_vorbis_flush_pushdata
#define stb_vorbis_get_comment qp_stb_vorbis_get_comment
#define stb_vorbis_get_error qp_stb_vorbis_get_error
#define stb_vorbis_get_file_offset qp_stb_vorbis_get_file_offset
#define stb_vorbis_get_frame_float qp_stb_vorbis_get_frame_float
#define stb_vorbis_get_frame_short qp_stb_vorbis_get_frame_short
#define stb_vorbis_get_frame_short_interleaved qp_stb_vorbis_get_frame_short_interleaved
#define stb_vorbis_get_info qp_stb_vorbis_get_info
#define stb_vorbis_get_sample_offset qp_stb_vorbis_get_sample_offset
#define stb_vorbis_get_samples_float qp_stb_vorbis_get_samples_float
#define stb_vorbis_get_samples_float_interleaved qp_stb_vorbis_get_samples_float_interleaved
#define stb_vorbis_get_samples_short qp_stb_vorbis_get_samples_short
#define stb_vorbis_get_samples_short_interleaved qp_stb_vorbis_get_samples_short_interleaved
#define stb_vorbis_info qp_stb_vorbis_info
#define stb_vorbis_open_file qp_stb_vorbis_open_file
#define stb_vorbis_open_file_section qp_stb_vorbis_open_file_section
#define stb_vorbis_open_filename qp_stb_vorbis_open_filename
#define stb_vorbis_open_memory qp_stb_vorbis_open_memory
#define stb_vorbis_open_pushdata qp_stb_vorbis_open_pushdata
#define stb_vorbis_seek qp_stb_vorbis_seek
#define stb_vorbis_seek_frame qp_stb_vorbis_seek_frame
#define stb_vorbis_seek_start qp_stb_vorbis_seek_start
#define stb_vorbis_stream_length_in_samples qp_stb_vorbis_stream_length_in_samples
#define stb_vorbis_stream_length_in_seconds qp_stb_vorbis_stream_length_in_seconds

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
#include "stb_vorbis_impl.h"
#pragma clang diagnostic pop
