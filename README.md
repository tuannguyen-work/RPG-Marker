# RPG-Marker

An iOS/iPadOS player for games made with RPG Maker. Import a game you own from
the Files app and play it with touch controls or a game controller.

> This app does not include, sell, host or distribute any games. All games must
> be legally obtained by the user. RPG Maker is a trademark of its respective
> owner; this project is not affiliated with or endorsed by it.

## Status

Early development. Planned engine support: RPG Maker MV/MZ (web runtime),
then XP/VX/VX Ace.

## Building

Requirements: Xcode 26 or later.

1. Open `RPG Maker.xcodeproj`.
2. Select the `RPG Maker` scheme and an iOS Simulator or device.
3. Build and run.

## Project structure

```
RPG Maker/
├── App/            entry point, dependency container, navigation
├── Core/           cross-cutting utilities (logging, …)
├── Domain/         models and service protocols
├── Features/       one folder per feature (View + ViewModel)
├── DesignSystem/   theme tokens and shared components
└── Resources/      asset catalog
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

Third-party components are listed in `THIRD_PARTY_NOTICES.md`.

The app's name, icon and branding are not licensed under the GPL and may not be
used for derived apps without permission.
