# RPG Deck

RPG Deck is an iOS player for games made with RPG Maker. Import a game you own from
the Files app and play it with on-screen controls.

> This app does not include, sell, host or distribute any games. All games must be legally obtained by the user. RPG Maker is a trademark of its respective
> owner; this project is not affiliated with or endorsed by it.

## Features

- Plays RPG Maker MV and MZ games (WKWebView) and XP, VX and VX Ace games (mkxp-z)
- Library with covers, search, filters, favorites and play time
- On-screen controls with adjustable size and opacity, pause menu, fast-forward
- Saves kept apart from games, synced with iCloud Drive, exportable as ZIP
- Illustrated in-app guide

## Building

Requirements: Xcode 26 or later, Homebrew `cmake meson ninja autoconf automake libtool pkg-config`,
and a Ruby on the Mac (used to cross-compile Ruby).

RPG Maker XP/VX/VX Ace games run in [mkxp-z](https://github.com/mkxp-z/mkxp-z), which is built
from source with its dependencies. Do this once per platform you build for (about 40 min each):

```sh
# iOS Simulator (arm64)
make -C ThirdParty/mkxp-deps everything      # SDL, OpenAL, FluidSynth, Ruby, … → ~/Library/Caches/RPGMarker
ThirdParty/mkxp-ios/build.sh                 # mkxp-z → ThirdParty/Build + Runtime/MKXP/Assets.bundle

# iPhone / iPad
make -C ThirdParty/mkxp-deps everything PLATFORM=iphoneos
ThirdParty/mkxp-ios/build.sh iphoneos
```

Then open `RPG Maker.xcodeproj`, pick the `RPG Maker` scheme and a destination, and run.

## Project structure

```
RPG Maker/            the app (the Xcode target keeps its original name)
├── App/              entry point, dependency container, navigation
├── Core/             logging, preferences, storage layout
├── Domain/           models and the library repository
├── Import/           ZIP/folder import, engine detection, covers
├── Runtime/          web runtime (MV/MZ), mkxp-z bridge (XP/VX/VX Ace), saves, iCloud
├── Features/         one folder per screen (library, details, player, guide, settings, …)
├── DesignSystem/     theme tokens and shared components
└── Resources/        asset catalog, licenses, privacy manifest
ThirdParty/           build scripts and patches for mkxp-z and its dependencies (SOURCES.md)
DemoGame/             generator for a test game (App Review, screenshots); not in the app
fastlane/             App Store metadata, screenshots and release lanes
```

## Releasing

`fastlane/README.md` lists the lanes. In short, with an App Store Connect API key in
`fastlane/.env` (see `fastlane/.env.example`):

```sh
fastlane screenshots   # 6.9" screenshots from the simulator
fastlane metadata      # App Store text
fastlane beta          # build and upload to TestFlight
fastlane release       # submit the latest build for review
```

## License

Copyright (C) 2026 The RPG-Marker Authors (see `AUTHORS`).

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version, with the additional permission described in `APP_STORE_EXCEPTION.md`.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See `LICENSE` for details.

Third-party components are listed in `THIRD_PARTY_NOTICES.md`; the exact revisions built into
the app are in `ThirdParty/SOURCES.md`.

The app's name, icon and artwork (the images in `RPG Maker/Resources/Assets.xcassets`) are not
covered by the GPL and may not be reused in other apps. The demo game's files are covered by
`DemoGame/LICENSES.txt`.

The app's name, icon and branding are not licensed under the GPL and may not be
used for derived apps without permission.

## Demo game

`python3 DemoGame/build_demo.py` (needs Pillow and ffmpeg) builds `DemoGame/build/RPG Deck Demo.zip`,
a small game that can be attached for App Review and is used for the in-game screenshot. It is not
bundled with the app. It is made from the RPG Maker MV corescript (MIT, vendored in
`DemoGame/runtime`), the Pixelify Sans font (OFL) and art, sounds and data made by the script (CC0). No RPG Maker RTP assets are used. See
`DemoGame/LICENSES.txt`.
