//
//  RootView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack {
            HomeView(viewModel: HomeViewModel(
                repository: dependencies.projectRepository,
                importer: dependencies.gameImporter
            ))
        }
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
}

#Preview {
    RootView()
        .environment(AppDependencies.preview)
}
