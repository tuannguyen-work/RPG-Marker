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
    @Environment(AppRouter.self) private var router
    @State private var isFilePickerPresented = false
    @State private var gamePendingDeletion: GameProject?

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
            Button("Import Game", systemImage: "plus") {
                isFilePickerPresented = true
            }
            .disabled(viewModel.importState != nil)
        }
        .fileImporter(isPresented: $isFilePickerPresented, allowedContentTypes: Self.importableTypes) { result in
            guard case .success(let url) = result else { return }
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
        .task { await viewModel.load() }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let game = viewModel.continueGame {
                    ContinueCard(game: game) {
                        router.push(.projectDetail(game.id))
                    }
                }

                if !viewModel.projects.isEmpty {
                    Text("All Games")
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.projects) { game in
                            Button {
                                router.push(.projectDetail(game.id))
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
    .environment(AppRouter())
    .preferredColorScheme(.dark)
}

#Preview("Empty") {
    let dependencies = AppDependencies(directories: .temporary(), projectRepository: InMemoryProjectRepository())
    NavigationStack {
        HomeView(viewModel: HomeViewModel(repository: dependencies.projectRepository, importer: dependencies.gameImporter))
    }
    .environment(AppRouter())
    .preferredColorScheme(.dark)
}
