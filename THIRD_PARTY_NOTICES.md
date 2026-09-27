# Third-Party Notices

Every third-party component that is compiled into or shipped with the app must
be listed here **before** it is merged, with its license and the obligation it
creates. Also add it to the in-app Settings › Acknowledgements screen
(`Acknowledgement.all` in `Features/Settings/SettingsView.swift`) with its
license text in `Resources/Licenses/`.

| Component | Version | License | Used for | Obligations |
|---|---|---|---|---|
| [stb_vorbis](https://github.com/nothings/stb) (`Runtime/Audio/stb_vorbis_impl.h`) | 1.22 | MIT or Public Domain (Unlicense), at our choice: MIT | Decoding Ogg Vorbis to WAV for RPG Maker MV games that ship only .ogg | Keep the copyright and license notice (end of the file); list in Acknowledgements |

## Rules

- Allowed without discussion: MIT, BSD-2/3-Clause, Apache-2.0, zlib, ISC,
  public domain / CC0.
- GPL-2.0-or-later and GPL-3.0(-or-later): allowed, the app is GPL-3.0-or-later.
  **GPL-2.0-only is not compatible** and must not be linked.
- LGPL: allowed (combined work is GPL-3.0-or-later).
- Anything else (custom, "non-commercial", unknown): not allowed until reviewed.
- Build mkxp-z with `enable-https` / OpenSSL **disabled**.
- Never bundle RPG Maker RTP files, fonts, or games owned by others.
