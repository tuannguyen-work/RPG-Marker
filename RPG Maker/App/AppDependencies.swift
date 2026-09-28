//
//  AppDependencies.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation
import Observation

/// Container for app-wide services, injected into the view tree via `.environment(_:)`.
/// Swap implementations here (e.g. `.preview`) instead of creating services inside views.
@Observable
final class AppDependencies {
    let directories: AppDirectories
    let projectRepository: any ProjectRepository
    let gameImporter: GameImporter
    let cloudSaves: CloudSaves

    init(directories: AppDirectories, projectRepository: any ProjectRepository) {
        self.directories = directories
        self.projectRepository = projectRepository
        self.gameImporter = GameImporter(directories: directories, repository: projectRepository)
        self.cloudSaves = CloudSaves(directories: directories)
    }

    static var live: AppDependencies {
        #if DEBUG
        // Launch with `-sampleData` to fill the library with sample games.
        if ProcessInfo.processInfo.arguments.contains("-sampleData") {
            return preview
        }
        #endif
        let directories = AppDirectories.live
        return AppDependencies(
            directories: directories,
            projectRepository: FileProjectRepository(fileURL: directories.libraryFile)
        )
    }

    static var preview: AppDependencies {
        AppDependencies(
            directories: .temporary(),
            projectRepository: InMemoryProjectRepository(projects: GameProject.samples)
        )
    }
}
