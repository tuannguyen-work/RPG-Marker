//
//  AppDependencies.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Observation

/// Container for app-wide services, injected into the view tree via `.environment(_:)`.
/// Swap implementations here (e.g. `.preview`) instead of creating services inside views.
@Observable
final class AppDependencies {
    let projectRepository: any ProjectRepository

    init(projectRepository: any ProjectRepository) {
        self.projectRepository = projectRepository
    }

    static var live: AppDependencies {
        AppDependencies(projectRepository: InMemoryProjectRepository())
    }

    static var preview: AppDependencies {
        AppDependencies(projectRepository: InMemoryProjectRepository(projects: GameProject.samples))
    }
}
