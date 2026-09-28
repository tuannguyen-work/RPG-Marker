# Third-Party Notices

Every third-party component that is compiled into or shipped with the app must
be listed here **before** it is merged, with its license and the obligation it
creates. Also add it to the in-app Settings › Acknowledgements screen
(`Acknowledgement.all` in `Features/Settings/SettingsView.swift`) with its
license text in `Resources/Licenses/`.

| Component | Version | License | Used for | Obligations |
|---|---|---|---|---|
| [stb_vorbis](https://github.com/nothings/stb) (`Runtime/Audio/stb_vorbis_impl.h`) | 1.22 | MIT or Public Domain (Unlicense), at our choice: MIT | Decoding Ogg Vorbis to WAV for RPG Maker MV games that ship only .ogg | Keep the copyright and license notice (end of the file); list in Acknowledgements |
| [mkxp-z](https://github.com/mkxp-z/mkxp-z), iOS fork by [RPGPlayer](https://github.com/am1guard/RPGPlayer-MKXP-Z) @ 2400ad2 (`ThirdParty/mkxp-ios`) | 2.4.2 | GPL-2.0-or-later | RPG Maker XP/VX/VX Ace runtime | Our changes published as `ThirdParty/mkxp-ios/patches/`; built without OpenSSL |
| [Ruby](https://github.com/mkxp-z/ruby) (mkxp-z branch) | 3.1.3 | Ruby License or BSD-2-Clause | Script interpreter for mkxp-z | Notice; our changes in `ThirdParty/mkxp-deps/patches/` |
| [SDL2](https://github.com/mkxp-z/SDL), SDL_image, SDL_sound, SDL_ttf (mkxp-z forks) | 2.28.1 | zlib | Window, input, image/audio decoding, text | Notice; SDL change in `ThirdParty/mkxp-deps/patches/` |
| [OpenAL Soft](https://github.com/kcat/openal-soft) | 1.24.3 | LGPL-2.0-or-later | Audio output for mkxp-z | Combined work is GPL; source and build scripts published |
| [PhysFS](https://github.com/icculus/physfs) | 3.2.0 | zlib | Game archive/filesystem access | Notice |
| [pixman](https://gitlab.freedesktop.org/pixman/pixman) | 0.42.2 | MIT | Bitmap operations | Notice |
| [FreeType](https://github.com/mkxp-z/freetype2) | mkxp-z fork | FreeType License (FTL) | Font rendering | Credit in documentation/Acknowledgements |
| [libpng](https://github.com/pnggroup/libpng) | 1.6.50 | libpng License | PNG decoding | Notice |
| [uchardet](https://gitlab.freedesktop.org/uchardet/uchardet) | 0.0.8 | MPL-1.1 / GPL-2.0+ / LGPL-2.1+ (we use GPL-2.0+) | Text encoding detection | — |
| [libogg, libvorbis, libtheora](https://github.com/xiph) | 1.3.6 / 1.3.7 / 1.2.0 | BSD-3-Clause | Ogg audio and video | Notice |
| [FluidSynth](https://github.com/FluidSynth/fluidsynth) | 2.6.1 | LGPL-2.1-or-later | MIDI synthesis for mkxp-z | Combined work is GPL; source and build scripts published |
| [GeneralUser GS](https://github.com/mrbumpy409/GeneralUser-GS) | 2.0.3 | GeneralUser GS License v2.0 (permissive) | Default MIDI soundfont | Keep license text |
| Liberation Sans (bundled by mkxp-z) | — | SIL OFL 1.1 | Default game font | Keep license with the font |
| WenQuanYi Micro Hei (bundled by mkxp-z) | — | Apache-2.0 or GPL-3.0 | CJK fallback font | Notice |

## Rules

- Allowed without discussion: MIT, BSD-2/3-Clause, Apache-2.0, zlib, ISC,
  public domain / CC0.
- GPL-2.0-or-later and GPL-3.0(-or-later): allowed, the app is GPL-3.0-or-later.
  **GPL-2.0-only is not compatible** and must not be linked.
- LGPL: allowed (combined work is GPL-3.0-or-later).
- Anything else (custom, "non-commercial", unknown): not allowed until reviewed.
- Build mkxp-z with `enable-https` / OpenSSL **disabled**.
- Never bundle RPG Maker RTP files, fonts, or games owned by others.

