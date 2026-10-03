//
//  SettingsView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import StoreKit
import SwiftUI

/// Controls, storage, about, legal notice, source code offer and third-party acknowledgements.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage(PreferenceKey.controlsOpacity) private var controlsOpacity = 0.9
    @AppStorage(PreferenceKey.controlsSize) private var controlsSize = ControlsSize.medium
    @AppStorage(PreferenceKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(PreferenceKey.iCloudSaves) private var iCloudSaves = true
    @AppStorage(PreferenceKey.hasSeenControlsGuide) private var hasSeenControlsGuide = false
    @Environment(\.requestReview) private var requestReview

    @State private var usage: StorageUsage?
    @State private var isClearingCache = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        HelpCenterView()
                    } label: {
                        Label("Guide", systemImage: "book.fill")
                    }
                    Button {
                        hasSeenControlsGuide = false
                    } label: {
                        Label("Show Controls Tips Again", systemImage: "hand.tap")
                    }
                    .disabled(!hasSeenControlsGuide)
                    Link(destination: AppInfo.supportURL) {
                        Label("Report a Problem", systemImage: "exclamationmark.bubble")
                    }
                    Button {
                        requestReview()
                    } label: {
                        Label("Rate the App", systemImage: "star")
                    }
                } header: {
                    Text("Help")
                } footer: {
                    if !hasSeenControlsGuide {
                        Text("Tips appear the next time you play a game.")
                    }
                }

                Section {
                    ControlsPreview(opacity: controlsOpacity, scale: controlsSize.scale)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("On-Screen Controls")
                }

                Section {
                    VStack(alignment: .leading) {
                        LabeledContent("Button Opacity", value: controlsOpacity.formatted(.percent.precision(.fractionLength(0))))
                        Slider(value: $controlsOpacity, in: 0.3...1, step: 0.05)
                    }
                    Picker("Button Size", selection: $controlsSize.animation(.spring(response: 0.3, dampingFraction: 0.7))) {
                        ForEach(ControlsSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    Toggle("Vibration", isOn: $hapticsEnabled)
                } footer: {
                    Text("Buttons fade further while they cover the game.")
                }

                Section {
                    Toggle(isOn: $iCloudSaves) {
                        Label("iCloud Saves", systemImage: "icloud")
                    }
                    .disabled(!CloudSaves.isAccountAvailable)
                } header: {
                    Text("Saves")
                } footer: {
                    if CloudSaves.isAccountAvailable {
                        Text("Saves sync through iCloud Drive, so you can continue on your other devices. They stay in iCloud if you delete a game and come back when you import it again.")
                    } else {
                        Text("Sign in to iCloud in the Settings app to sync saves between your devices.")
                    }
                }

                Section {
                    LabeledContent("Games", value: usage.map { DirectorySize.formatted($0.games) } ?? "…")
                    LabeledContent("Saves", value: usage.map { DirectorySize.formatted($0.saves) } ?? "…")
                    LabeledContent("Audio Cache", value: usage.map { DirectorySize.formatted($0.cache) } ?? "…")
                    Button("Clear Audio Cache", role: .destructive) {
                        Task { await clearCache() }
                    }
                    .disabled(isClearingCache || (usage?.cache ?? 0) == 0)
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Converted game music is cached so it starts faster. Clearing it is safe; it is rebuilt when needed.")
                }
                .contentTransition(.numericText())

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
                    Text("This app is a player. Apart from its built-in demo, it does not include, sell, host or distribute any games. Only import games you have legally obtained.")
                    Text("RPG Maker is a trademark of its respective owner. This app is not affiliated with or endorsed by it.")
                }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

                Section {
                    Link(destination: AppInfo.privacyPolicyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
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
                    // GPL source offer: plain directions rather than a link (the App Store page links to it).
                    Text("This app is free software: you can redistribute and modify it under the GPL, version 3 or later. Its complete source code is available from the developer website listed on its App Store page. The app's name, icon and artwork are not covered by the GPL.")
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
        .task { await refreshUsage() }
    }

    private func refreshUsage() async {
        let directories = dependencies.directories
        let result = await Task.detached(priority: .utility) { StorageUsage.measure(directories) }.value
        withAnimation { usage = result }
    }

    private func clearCache() async {
        isClearingCache = true
        await Task.detached { OggTranscoder.clearCache() }.value
        await refreshUsage()
        isClearingCache = false
    }
}

nonisolated struct StorageUsage: Sendable {
    let games: Int64
    let saves: Int64
    let cache: Int64

    static func measure(_ directories: AppDirectories) -> StorageUsage {
        StorageUsage(
            games: DirectorySize.bytes(at: directories.games),
            saves: DirectorySize.bytes(at: directories.saves),
            cache: DirectorySize.bytes(at: OggTranscoder.cacheDirectory)
        )
    }
}

/// Live miniature of the gamepad so opacity and size changes are visible right away.
private struct ControlsPreview: View {
    let opacity: Double
    let scale: CGFloat

    var body: some View {
        ZStack {
            Image(.coverForest)
                .interpolation(.none)
                .resizable()
                .scaledToFill()
                .frame(height: 120)
                .clipped()
            HStack {
                Image(systemName: "dpad.fill")
                    .font(.system(size: 44))
                Spacer()
                HStack(spacing: 10) {
                    Circle().frame(width: 34, height: 34).overlay(Text("B").font(.headline.weight(.heavy)).foregroundStyle(Theme.Colors.background)).offset(y: 12)
                    Circle().frame(width: 34, height: 34).overlay(Text("A").font(.headline.weight(.heavy)).foregroundStyle(Theme.Colors.background))
                }
            }
            .foregroundStyle(Theme.Colors.textPrimary)
            .scaleEffect(scale)
            .padding(.horizontal, 36)
            .opacity(opacity)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
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
            // In the bundled demo game (DemoGame/).
            Acknowledgement(name: "RPG Deck Demo (corescript, pixi.js, Pixelify Sans)", license: "MIT / OFL 1.1 / CC0", licenseResource: "License-DemoGame"),
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
    static let supportURL = URL(string: "https://github.com/tuannguyen-work/RPG-Marker/issues")!
    static let privacyPolicyURL = URL(string: "https://github.com/tuannguyen-work/RPG-Marker/blob/main/PRIVACY.md")!
}

#Preview {
    SettingsView()
        .environment(AppDependencies.preview)
}
