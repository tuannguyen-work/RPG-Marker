# Third-party sources in the release build

The XP/VX/VX Ace runtime is compiled from these exact revisions. `mkxp-deps/Makefile` and
`mkxp-ios/build.sh` fetch them (branch checkouts are pinned with `PIN`), then apply the patches in
`mkxp-deps/patches` and `mkxp-ios/patches`. Together with this repository they are the complete
corresponding source of the app.

| Component | Repository | Commit | License |
|---|---|---|---|
| mkxp-z (RPGPlayer fork) | https://github.com/am1guard/RPGPlayer-MKXP-Z | `2400ad2f6560a00b0e34b2bcc3a3c3f95433dad8` | GPL-2.0-or-later |
| Ruby 3.1 (mkxp-z) | https://github.com/mkxp-z/ruby | `4d85560cf65938d7883a323bf553acad1faf5eae` | Ruby / BSD-2-Clause |
| SDL 2.28 (mkxp-z) | https://github.com/mkxp-z/SDL | `d3ac4c3742a405e719071fc4f5a7ba8a125c76a1` | zlib |
| SDL_image (mkxp-z) | https://github.com/mkxp-z/SDL_image | `d3c6d5963dbe438bcae0e2b6f3d7cfea23d02829` | zlib |
| SDL_sound (mkxp-z) | https://github.com/mkxp-z/SDL_sound | `cfb2533eb3bac3700015cbd87cc623bea1467239` | zlib |
| SDL_ttf (mkxp-z) | https://github.com/mkxp-z/SDL_ttf | `0d5909ee2f1c95770d7fe76eb2fbd66ece26a5bf` | zlib |
| FreeType (mkxp-z) | https://github.com/mkxp-z/freetype2 | `4d8db130ea4342317581bab65fc96365ce806b77` | FreeType License |
| OpenAL Soft 1.24.3 | https://github.com/kcat/openal-soft | `dc7d7054a5b4f3bec1dc23a42fd616a0847af948` | LGPL-2.0-or-later |
| FluidSynth 2.6.1 | https://github.com/FluidSynth/fluidsynth | `71e85b2ca6bf48641ba7e2261d8f2640ae473773` | LGPL-2.1-or-later |
| PhysicsFS 3.2.0 | https://github.com/icculus/physfs | `eb3383b532c5f74bfeb42ec306ba2cf80eed988c` | zlib |
| pixman 0.42.2 | https://gitlab.freedesktop.org/pixman/pixman | `37216a32839f59e8dcaa4c3951b3fcfc3f07852c` | MIT |
| libpng 1.6.50 | https://github.com/pnggroup/libpng | `2b978915d82377df13fcbb1fb56660195ded868a` | libpng License |
| uchardet 0.0.8 | https://gitlab.freedesktop.org/uchardet/uchardet | `ae6302a016088ad07177f86d417b20010053632b` | MPL-1.1 / GPL-2.0+ / LGPL-2.1+ |
| libogg 1.3.6 | https://github.com/xiph/ogg | `be05b13e98b048f0b5a0f5fa8ce514d56db5f822` | BSD-3-Clause |
| libvorbis 1.3.7 | https://github.com/xiph/vorbis | `0657aee69dec8508a0011f47f3b69d7538e9d262` | BSD-3-Clause |
| libtheora 1.2.0 | https://github.com/xiph/theora | `8e4808736e9c181b971306cc3f05df9e61354004` | BSD-3-Clause |
| GeneralUser GS (soundfont) | https://github.com/mrbumpy409/GeneralUser-GS | see `SOUNDFONT_REVISION` in `mkxp-ios/build.sh` | GeneralUser GS License |

The LGPL libraries are linked statically. Because the whole app's source is published here, you can
rebuild it with modified versions of them, as the LGPL requires.
