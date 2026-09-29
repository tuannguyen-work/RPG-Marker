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
    @State private var detailGame: GameProject?
    /// Started from the detail sheet: presented once the sheet is gone.
    @State private var pendingPlay: GameProject?
    @State private var isSyncingSaves = false
    @State private var isHelpPresented = false
    @State private var helpTopic: GuideTopic?
    /// The game in the player, kept after it closes so its new saves can be uploaded.
    @State private var sessionGame: GameProject?
    @Namespace private var transition

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    /// 7z and RAR can be picked so the user gets a clear "not supported yet" message instead of a greyed-out file.
    private static let importableTypes: [UTType] = [.zip, .folder]
        + ["7z", "rar"].compactMap { UTType(filenameExtension: $0) }

    var body: some View {
        Group {
            if viewModel.projects.isEmpty && !viewModel.isLoading && viewModel.importState == nil {
                EmptyLibraryView {
                    isFilePickerPresented = true
                } onDemo: {
                    playDemo()
                } onHelp: {
                    showHelp(.importing)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                library
            }
        }
        .background { AppBackground(style: .sky) }
        .navigationTitle("Library")
        .searchable(text: $viewModel.searchText, prompt: "Search Games")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", image: .iconSettings) {
                    isSettingsPresented = true
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Guide", image: .iconHelp) {
                    showHelp(nil)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Import Game", image: .iconAdd) {
                    isFilePickerPresented = true
                }
                .disabled(viewModel.importState != nil)
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .sheet(isPresented: $isHelpPresented) {
            HelpSheet(initialTopic: helpTopic, onPlayDemo: HomeViewModel.demoGameURL == nil ? nil : {
                isHelpPresented = false
                playDemo()
            })
        }
        .sheet(item: $detailGame, onDismiss: {
            if let game = pendingPlay {
                pendingPlay = nil
                play(game)
            }
        }) { game in
            GameDetailView(gameID: game.id, viewModel: viewModel) { game in
                pendingPlay = game
                detailGame = nil
            }
            .zoomTransition(sourceID: game.id, in: transition)
        }
        .toast($viewModel.toast)
        .overlay(alignment: .top) {
            if isSyncingSaves {
                SyncingBadge()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSyncingSaves)
        .fileImporter(isPresented: $isFilePickerPresented, allowedContentTypes: Self.importableTypes) { result in
            guard case .success(let url) = result else { return }
            importGame(from: url)
        }
        // "Open in…" / share sheet from Files and other apps.
        .onOpenURL { url in
            guard url.isFileURL else { return }
            importGame(from: url)
        }
        .overlay {
            if let state = viewModel.importState {
                ImportStatusView(state: state) {
                    viewModel.importState = nil
                } onHelp: {
                    viewModel.importState = nil
                    showHelp(.troubleshooting)
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
            Text("The game files and its saves are removed from this device. Export the saves from the game's details first to keep them.")
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
            if let game = sessionGame {
                sessionGame = nil
                Task { await dependencies.cloudSaves.sync(game, timeout: .seconds(30)) }
            }
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
            if arguments.contains("-showDetail") { detailGame = viewModel.projects.first }
            if arguments.contains("-playDemo") { playDemo() }
            if let index = arguments.firstIndex(of: "-showGuide") {
                showHelp(arguments.indices.contains(index + 1) ? GuideTopic(rawValue: arguments[index + 1]) : nil)
            }
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
        guard game.engine.isPlayable else {
            unsupportedGame = game
            return
        }
        guard !isSyncingSaves else { return }
        Task {
            // Pull saves made on other devices first; the badge only shows when it takes a moment.
            let badge = Task {
                try await Task.sleep(for: .milliseconds(400))
                isSyncingSaves = true
            }
            await dependencies.cloudSaves.sync(game, timeout: .seconds(6))
            badge.cancel()
            isSyncingSaves = false
            sessionGame = game
            playingGame = game
        }
    }

    /// Adds the bundled demo (once) and starts it.
    private func playDemo() {
        Task {
            if let game = await viewModel.importDemoGame() {
                play(game)
            }
        }
    }

    private func showHelp(_ topic: GuideTopic?) {
        helpTopic = topic
        isHelpPresented = true
    }

    private func importGame(from url: URL) {
        Task {
            // A game played before on this or another device gets its iCloud saves back.
            if let game = await viewModel.importGame(from: url) {
                await dependencies.cloudSaves.sync(game)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $viewModel.sort.animation(.snappy)) {
                ForEach(LibrarySort.allCases) { sort in
                    Label(sort.title, systemImage: sort.systemImage).tag(sort)
                }
            }
        } label: {
            Label("Sort", image: .iconSort)
        }
        .disabled(viewModel.projects.count < 2)
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let game = viewModel.continueGame, !viewModel.isNarrowed {
                    ContinueCard(game: game) {
                        play(game)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if !viewModel.projects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(viewModel.isNarrowed ? "Results" : "All Games")
                                .font(Theme.Fonts.title)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text("\(viewModel.visibleProjects.count)")
                                .font(Theme.Fonts.pixelLabel)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .contentTransition(.numericText())
                        }
                        if viewModel.availableFilters.count > 1 {
                            LibraryFilterBar(filters: viewModel.availableFilters, selection: $viewModel.filter)
                                .padding(.horizontal, -20)
                        }
                    }

                    let games = viewModel.visibleProjects
                    if games.isEmpty {
                        noResults
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(games) { game in
                                card(for: game)
                                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
            .padding(20)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.visibleProjects.map(\.id))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.isNarrowed)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await viewModel.load() }
    }

    private func card(for game: GameProject) -> some View {
        Button {
            play(game)
        } label: {
            GameCard(game: game, isHighlighted: game.id == viewModel.continueGame?.id)
        }
        .buttonStyle(.pressable)
        .matchedTransitionSourceIfAvailable(id: game.id, in: transition)
        .overlay(alignment: .bottomTrailing) {
            Button {
                detailGame = game
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .padding(.trailing, 2)
            .padding(.bottom, 6)
            .accessibilityLabel("Details for \(game.name)")
        }
        .contextMenu {
            Button("Play", systemImage: "play.fill") {
                play(game)
            }
            Button(game.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                   systemImage: game.isFavorite ? "star.slash" : "star") {
                Task { await viewModel.toggleFavorite(game) }
            }
            Button("Details", systemImage: "info.circle") {
                detailGame = game
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                gamePendingDeletion = game
            }
        } preview: {
            GameCard(game: game)
                .frame(width: 220)
                .environment(dependencies)
        }
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            Image(systemName: viewModel.filter == .favorites && viewModel.searchText.isEmpty ? "star" : "magnifyingglass")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("No games found")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Try a different name or filter.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .transition(.opacity)
    }
}

private extension View {
    /// iOS 18 zoom from the tapped card into the sheet; the standard slide before that.
    @ViewBuilder
    func zoomTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }

    @ViewBuilder
    func matchedTransitionSourceIfAvailable(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
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
