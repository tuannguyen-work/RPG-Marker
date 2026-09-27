//
//  HomeView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(AppRouter.self) private var router

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        Group {
            if viewModel.projects.isEmpty && !viewModel.isLoading {
                EmptyLibraryView {
                    Task { await viewModel.importGame() }
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
                Task { await viewModel.importGame() }
            }
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
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

#Preview("Library") {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(repository: InMemoryProjectRepository(projects: GameProject.samples)))
    }
    .environment(AppRouter())
    .preferredColorScheme(.dark)
}

#Preview("Empty") {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(repository: InMemoryProjectRepository()))
    }
    .environment(AppRouter())
    .preferredColorScheme(.dark)
}
