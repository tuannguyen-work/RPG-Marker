//
//  HomeViewModel.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation
import Observation
import os

@Observable
final class HomeViewModel {
    private(set) var projects: [GameProject] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let repository: any ProjectRepository

    init(repository: any ProjectRepository) {
        self.repository = repository
    }

    /// The most recently played game, shown in the "Continue" panel.
    var continueGame: GameProject? {
        projects
            .filter { $0.lastPlayedAt != nil }
            .max { ($0.lastPlayedAt ?? .distantPast) < ($1.lastPlayedAt ?? .distantPast) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await repository.fetchAll()
        } catch {
            Logger.data.error("Failed to load projects: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Placeholder until the import flow (Files picker + engine detection) exists.
    func importGame() async {
        let project = GameProject(name: "New Game \(projects.count + 1)", engine: .mz)
        do {
            try await repository.save(project)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
