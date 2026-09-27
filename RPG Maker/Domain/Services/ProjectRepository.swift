//
//  ProjectRepository.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

protocol ProjectRepository: Sendable {
    func fetchAll() async throws -> [GameProject]
    func save(_ project: GameProject) async throws
    func delete(id: GameProject.ID) async throws
}

/// Non-persistent implementation, used until real storage (SwiftData / files) is added.
actor InMemoryProjectRepository: ProjectRepository {
    private var projects: [GameProject.ID: GameProject]

    init(projects: [GameProject] = []) {
        self.projects = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    }

    func fetchAll() async throws -> [GameProject] {
        projects.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ project: GameProject) async throws {
        projects[project.id] = project
    }

    func delete(id: GameProject.ID) async throws {
        projects[id] = nil
    }
}
