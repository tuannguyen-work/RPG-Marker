//
//  GameDetailView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI
import UniformTypeIdentifiers

/// A game's page: stats, saves and management (rename, favorite, delete).
struct GameDetailView: View {
    let gameID: GameProject.ID
    let viewModel: HomeViewModel
    let onPlay: (GameProject) -> Void

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var sizeOnDisk: Int64?
    @State private var slots: [SaveLibrary.Slot] = []
    @State private var hasSaves = false
    @State private var exportedSaves: URL?
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var isConfirmingDelete = false
    @State private var isConfirmingClearSaves = false
    @State private var favoriteBounce = 0
    @State private var isImportingSaves = false
    @State private var isSyncing = false

    private var game: GameProject? {
        viewModel.projects.first { $0.id == gameID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let game {
                    content(game)
                } else {
                    Color.clear
                }
            }
            .background { AppBackground(style: .pattern) }
            .navigationTitle(game?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .toast(Binding(get: { viewModel.toast }, set: { viewModel.toast = $0 }))
        .tint(Theme.Colors.ember)
        .preferredColorScheme(.dark)
        .task(id: gameID) { await refresh() }
        .onChange(of: game == nil) { _, isGone in
            if isGone { dismiss() }
        }
    }

    private func content(_ game: GameProject) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header(game)
                actions(game)
                stats(game)
                saves(game)
                manage(game)
            }
            .padding(20)
        }
        .alert("Rename Game", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
                .submitLabel(.done)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task { await viewModel.rename(game, to: newName) }
            }
        }
        .confirmationDialog("Delete this game?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete \(game.name)", role: .destructive) {
                Task { await viewModel.delete(game) }
            }
        } message: {
            Text(CloudSaves.isEnabled && CloudSaves.isAccountAvailable
                 ? "The game files are removed from this device. Its saves stay in iCloud and come back if you import the game again."
                 : "The game files and its saves are removed from this device. Export the saves first to keep them.")
        }
        .fileImporter(
            isPresented: $isImportingSaves,
            allowedContentTypes: [.zip, .data],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }
            Task { await importSaves(game, from: urls) }
        }
        .confirmationDialog("Delete all saves?", isPresented: $isConfirmingClearSaves, titleVisibility: .visible) {
            Button("Delete Saves", role: .destructive) {
                Task { await clearSaves(game) }
            }
        } message: {
            Text("Progress in \(game.name) will be lost on this device and in iCloud. This can't be undone.")
        }
    }

    // MARK: - Sections

    private func header(_ game: GameProject) -> some View {
        GameCover(game: game)
            .aspectRatio(16 / 10, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    EngineBadge(engine: game.engine)
                    Text(game.name)
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.8), radius: 4)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(6)
            .pixelFrame(.window)
    }

    private func actions(_ game: GameProject) -> some View {
        HStack(spacing: 12) {
            Button {
                onPlay(game)
            } label: {
                Label(game.playTime > 0 ? "Resume" : "Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pixel)

            Button {
                favoriteBounce += 1
                Task { await viewModel.toggleFavorite(game) }
            } label: {
                Image(systemName: game.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(game.isFavorite ? Theme.Colors.gold : Theme.Colors.textPrimary)
                    .symbolEffect(.bounce, value: favoriteBounce)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pixelSecondary)
            .accessibilityLabel(game.isFavorite ? "Remove from Favorites" : "Add to Favorites")
            .sensoryFeedback(.success, trigger: favoriteBounce)
        }
    }

    private func stats(_ game: GameProject) -> some View {
        Panel(title: "Details") {
            StatRow(label: "Play Time", value: game.formattedPlayTime)
            StatRow(label: "Last Played", value: game.lastPlayedAt.map { $0.formatted(.relative(presentation: .named)) } ?? String(localized: "Never"))
            StatRow(label: "Added", value: game.addedAt.formatted(date: .abbreviated, time: .omitted))
            StatRow(label: "Engine", value: game.engine.displayName)
            StatRow(label: "Size", value: sizeOnDisk.map(DirectorySize.formatted) ?? "…")
        }
    }

    private func saves(_ game: GameProject) -> some View {
        Panel(title: "Saves") {
            if slots.isEmpty {
                Text(hasSaves ? "Game settings only, no save files yet." : "No saves yet. Your progress appears here after you save in the game.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(slots) { slot in
                    StatRow(
                        label: "File \(slot.number)",
                        value: slot.modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? ""
                    )
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }

            HStack(spacing: 10) {
                Button {
                    isImportingSaves = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                if hasSaves, let exportedSaves {
                    ShareLink(item: exportedSaves) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
                if hasSaves {
                    Button(role: .destructive) {
                        isConfirmingClearSaves = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.Colors.ember)
                    }
                    .accessibilityLabel("Delete Saves")
                }
            }
            .buttonStyle(.pixelCompact)
            .padding(.top, 4)

            if CloudSaves.isEnabled && CloudSaves.isAccountAvailable {
                HStack(spacing: 6) {
                    Image(systemName: isSyncing ? "arrow.triangle.2.circlepath.icloud" : "checkmark.icloud")
                        .symbolEffect(.pulse, isActive: isSyncing)
                        .contentTransition(.symbolEffect(.replace))
                    Text(isSyncing ? "Syncing with iCloud…" : "Saved in iCloud")
                }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .animation(.default, value: isSyncing)
            }
        }
        .animation(.snappy, value: slots)
    }

    private func manage(_ game: GameProject) -> some View {
        Panel(title: "Manage") {
            Button {
                newName = game.name
                isRenaming = true
            } label: {
                ManageRow(title: "Rename", systemImage: "pencil")
            }
            Divider().overlay(Theme.Colors.textSecondary.opacity(0.3))
            Button {
                isConfirmingDelete = true
            } label: {
                ManageRow(title: "Delete Game", systemImage: "trash", isDestructive: true)
            }
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Data

    /// Shows what is on this device right away, then again after merging with iCloud.
    private func refresh() async {
        await refreshLocal()
        guard let game, CloudSaves.isEnabled, CloudSaves.isAccountAvailable else { return }
        isSyncing = true
        await dependencies.cloudSaves.sync(game)
        isSyncing = false
        await refreshLocal()
    }

    private func refreshLocal() async {
        guard let game else { return }
        let directories = dependencies.directories
        let library = SaveLibrary(game: game, directories: directories)
        let result = await Task.detached(priority: .utility) {
            let size = DirectorySize.bytes(at: directories.gameDirectory(for: game.id))
                + DirectorySize.bytes(at: directories.saveDirectory(for: game.id))
            let slots = library.slots()
            let hasSaves = library.hasSaves
            let archive = hasSaves ? try? library.exportArchive() : nil
            return (size, slots, hasSaves, archive)
        }.value
        sizeOnDisk = result.0
        slots = result.1
        hasSaves = result.2
        exportedSaves = result.3
    }

    private func clearSaves(_ game: GameProject) async {
        let library = SaveLibrary(game: game, directories: dependencies.directories)
        let cloud = dependencies.cloudSaves
        await Task.detached {
            library.removeAll()
            cloud.removeAll(for: game)
        }.value
        viewModel.toast = .info(String(localized: "Saves deleted"))
        await refreshLocal()
    }

    private func importSaves(_ game: GameProject, from urls: [URL]) async {
        let library = SaveLibrary(game: game, directories: dependencies.directories)
        let result = await Task.detached { Result { try library.importSaves(from: urls) } }.value
        switch result {
        case .success(let count):
            viewModel.toast = .success(count == 1 ? String(localized: "Imported 1 save file") : String(localized: "Imported \(count) save files"))
            await refresh()
        case .failure(let error):
            viewModel.toast = .error(error.localizedDescription)
        }
    }
}

/// Titled RPG window used for the detail sections.
private struct Panel<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: Theme.Spacing.sm) {
                PixelCursor()
                Text(title)
                    .font(Theme.Fonts.pixelLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.gold)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelFrame(.window)
    }
}

private struct StatRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.Colors.textPrimary)
        }
        .font(Theme.Fonts.pixelLabel)
        .accessibilityElement(children: .combine)
    }
}

private struct ManageRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isDestructive = false

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(Theme.Fonts.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .foregroundStyle(isDestructive ? Theme.Colors.ember : Theme.Colors.textPrimary)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
