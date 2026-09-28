//
//  HomeView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(AppDependencies.self) private var dependencies
    @State private var isFilePickerPresented = false
    @State private var gamePendingDeletion: GameProject?
    @State private var playingGame: GameProject?
    @State private var unsupportedGame: GameProject?
    @State private var isSettingsPresented = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    /// 7z and RAR can be picked so the user gets a clear "not supported yet" message instead of a greyed-out file.
    private static let importableTypes: [UTType] = [.zip, .folder]
        + ["7z", "rar"].compactMap { UTType(filenameExtension: $0) }

    var body: some View {
        Group {
            if viewModel.projects.isEmpty && !viewModel.isLoading {
                EmptyLibraryView {
                    isFilePickerPresented = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                library
            }
        }
        .background { AppBackground(style: .sky) }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") {
                    isSettingsPresented = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Import Game", systemImage: "plus") {
                    isFilePickerPresented = true
                }
                .disabled(viewModel.importState != nil)
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .fileImporter(isPresented: $isFilePickerPresented, allowedContentTypes: Self.importableTypes) { result in
            guard case .success(let url) = result else { return }
            Task { await viewModel.importGame(from: url) }
        }
        // "Open in…" / share sheet from Files and other apps.
        .onOpenURL { url in
            guard url.isFileURL else { return }
            Task { await viewModel.importGame(from: url) }
        }
        .overlay {
            if let state = viewModel.importState {
                ImportStatusView(state: state) {
                    viewModel.importState = nil
                }
            }
        }
        .confirmationDialog(
            "Delete this game?",
            isPresented: Binding(get: { gamePendingDeletion != nil }, set: { if !$0 { gamePendingDeletion = nil } }),
            presenting: gamePendingDeletion
        ) { game in
            Button("Delete \(game.name)", role: .destructive) {
                Task { await viewModel.delete(game) }
            }
        } message: { _ in
            Text("The game files are removed from this device. You can import it again later.")
        }
        .alert(
            "Not playable yet",
            isPresented: Binding(get: { unsupportedGame != nil }, set: { if !$0 { unsupportedGame = nil } }),
            presenting: unsupportedGame
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { game in
            Text("RPG Maker \(game.engine.displayName) games will be playable in a future update. MV and MZ games can be played now.")
        }
        .fullScreenCover(item: $playingGame, onDismiss: {
            Task { await viewModel.load() }
        }) { game in
            if game.engine.usesWebRuntime {
                PlayerView(viewModel: PlayerViewModel(
                    game: game,
                    directories: dependencies.directories,
                    repository: dependencies.projectRepository
                ))
            } else {
                RGSSPlayerView(game: game, directories: dependencies.directories, repository: dependencies.projectRepository)
            }
        }
        .task {
            await viewModel.load()
            #if DEBUG
            // Launch with `-autoplay` (first playable game) or `-autoplay <part of a name>`.
            let arguments = ProcessInfo.processInfo.arguments
            isSettingsPresented = arguments.contains("-showSettings")
            if let index = arguments.firstIndex(of: "-autoplay") {
                let name = arguments.indices.contains(index + 1) ? arguments[index + 1] : ""
                playingGame = viewModel.projects.first {
                    $0.engine.isPlayable && (name.isEmpty || $0.name.localizedCaseInsensitiveContains(name))
                }
            }
            #endif
        }
    }

    private func play(_ game: GameProject) {
        if game.engine.isPlayable {
            playingGame = game
        } else {
            unsupportedGame = game
        }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let game = viewModel.continueGame {
                    ContinueCard(game: game) {
                        play(game)
                    }
                }

                if !viewModel.projects.isEmpty {
                    Text("All Games")
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.projects) { game in
                            Button {
                                play(game)
                            } label: {
                                GameCard(game: game, isHighlighted: game.id == viewModel.continueGame?.id)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    gamePendingDeletion = game
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

#Preview("Library") {
    let dependencies = AppDependencies.preview
    NavigationStack {
        HomeView(viewModel: HomeViewModel(repository: dependencies.projectRepository, importer: dependencies.gameImporter))
    }
    .environment(dependencies)
    .preferredColorScheme(.dark)
}

#Preview("Empty") {
    let dependencies = AppDependencies(directories: .temporary(), projectRepository: InMemoryProjectRepository())
    NavigationStack {
        HomeView(viewModel: HomeViewModel(repository: dependencies.projectRepository, importer: dependencies.gameImporter))
    }
    .environment(dependencies)
    .preferredColorScheme(.dark)
}
