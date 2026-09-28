//
//  SettingsView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// About, legal notice, source code offer and third-party acknowledgements.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Version", value: AppInfo.version)
                    Button("Show Introduction Again") {
                        dismiss()
                        hasCompletedOnboarding = false
                    }
                } header: {
                    Text(AppInfo.name)
                }

                Section("Legal") {
                    Text("This app is a player. It does not include, sell, host or distribute any games. Only import games you have legally obtained.")
                    Text("RPG Maker is a trademark of its respective owner. This app is not affiliated with or endorsed by it.")
                }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

                Section {
                    Link(destination: AppInfo.sourceCodeURL) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    NavigationLink("GNU General Public License v3") {
                        LicenseTextView(title: "GPL-3.0", resource: "License-GPL-3.0")
                    }
                    NavigationLink("App Store Exception") {
                        LicenseTextView(title: "App Store Exception", resource: "License-AppStoreException")
                    }
                } header: {
                    Text("Open Source")
                } footer: {
                    Text("This app is free software: you can redistribute and modify it under the GPL, version 3 or later. The app's name, icon and artwork are not covered by the GPL.")
                }

                Section("Acknowledgements") {
                    ForEach(Acknowledgement.all) { item in
                        NavigationLink {
                            LicenseTextView(title: item.name, resource: item.licenseResource)
                        } label: {
                            LabeledContent(item.name, value: item.license)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground(style: .pattern) }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.Colors.ember)
        .preferredColorScheme(.dark)
    }
}

/// Shows a bundled license text file (Resources/Licenses).
struct LicenseTextView: View {
    let title: String
    let resource: String

    private var text: String {
        Bundle.main.url(forResource: resource, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Theme.Colors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Third-party code compiled into the app. Keep in sync with THIRD_PARTY_NOTICES.md.
struct Acknowledgement: Identifiable {
    let name: String
    let license: String
    let licenseResource: String
    var id: String { name }

    static var all: [Acknowledgement] {
        let base = [
            Acknowledgement(name: "stb_vorbis", license: "MIT", licenseResource: "License-stb_vorbis"),
        ]
        return MKXPIsAvailable() ? base + rgssRuntime : base
    }

    /// The RPG Maker XP / VX / VX Ace runtime and what it bundles (ThirdParty/).
    private static let rgssRuntime = [
        Acknowledgement(name: "mkxp-z", license: "GPL-2.0-or-later", licenseResource: "License-mkxp-z"),
        Acknowledgement(name: "Ruby", license: "Ruby / BSD-2-Clause", licenseResource: "License-Ruby"),
        Acknowledgement(name: "SDL", license: "zlib", licenseResource: "License-SDL2"),
        Acknowledgement(name: "SDL_image", license: "zlib", licenseResource: "License-SDL_image"),
        Acknowledgement(name: "SDL_sound", license: "zlib", licenseResource: "License-SDL_sound"),
        Acknowledgement(name: "SDL_ttf", license: "zlib", licenseResource: "License-SDL_ttf"),
        Acknowledgement(name: "OpenAL Soft", license: "LGPL-2.0-or-later", licenseResource: "License-OpenAL-Soft"),
        Acknowledgement(name: "FluidSynth", license: "LGPL-2.1-or-later", licenseResource: "License-FluidSynth"),
        Acknowledgement(name: "PhysicsFS", license: "zlib", licenseResource: "License-PhysFS"),
        Acknowledgement(name: "pixman", license: "MIT", licenseResource: "License-pixman"),
        Acknowledgement(name: "FreeType", license: "FreeType License", licenseResource: "License-FreeType"),
        Acknowledgement(name: "libpng", license: "libpng License", licenseResource: "License-libpng"),
        Acknowledgement(name: "uchardet", license: "MPL-1.1 / GPL / LGPL", licenseResource: "License-uchardet"),
        Acknowledgement(name: "Ogg, Vorbis, Theora", license: "BSD-3-Clause", licenseResource: "License-Xiph"),
        Acknowledgement(name: "Liberation Sans", license: "SIL OFL 1.1", licenseResource: "License-Liberation"),
        Acknowledgement(name: "WenQuanYi Micro Hei", license: "Apache-2.0", licenseResource: "License-WenQuanYi"),
        Acknowledgement(name: "GeneralUser GS (MIDI sounds)", license: "GeneralUser GS License", licenseResource: "License-GeneralUser-GS"),
    ]
}

enum AppInfo {
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
    }

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }

    /// GPL source code offer: must point at the source of this exact release.
    static let sourceCodeURL = URL(string: "https://github.com/tuannguyen-work/RPG-Marker")!
}

#Preview {
    SettingsView()
}
