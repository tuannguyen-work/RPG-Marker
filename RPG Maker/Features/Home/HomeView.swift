//
//  HomeView.swift
//  RPG Maker
//

import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(AppRouter.self) private var router

    var body: some View {
        List(viewModel.projects) { project in
            Button {
                router.push(.projectDetail(project.id))
            } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(project.name)
                        .font(.headline)
                    Text(project.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if viewModel.projects.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("No Projects", systemImage: "gamecontroller", description: Text("Tap + to create your first game."))
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            Button("New Project", systemImage: "plus") {
                Task { await viewModel.createProject() }
            }
        }
        .task { await viewModel.load() }
    }
}

#Preview {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(repository: InMemoryProjectRepository(projects: GameProject.samples)))
    }
    .environment(AppRouter())
}
