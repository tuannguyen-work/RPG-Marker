//
//  RootView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var router = AppRouter()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView(viewModel: HomeViewModel(repository: dependencies.projectRepository))
                .navigationDestination(for: Route.self, destination: destination)
        }
        .environment(router)
        .tint(Theme.Colors.ember)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .projectDetail(let id):
            Text("Project \(id.uuidString)")
        }
    }
}

#Preview {
    RootView()
        .environment(AppDependencies.preview)
}
