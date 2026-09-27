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
    enum ImportState: Equatable {
        case importing(progress: Double)
        case failed(message: String)
    }

    private(set) var projects: [GameProject] = []
    private(set) var isLoading = false
    var importState: ImportState?
    var errorMessage: String?

    private let repository: any ProjectRepository
    private let importer: GameImporter

    init(repository: any ProjectRepository, importer: GameImporter) {
        self.repository = repository
        self.importer = importer
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

    func importGame(from url: URL) async {
        importState = .importing(progress: 0)
        do {
            _ = try await importer.importGame(from: url) { [weak self] progress in
                Task { @MainActor in
                    guard case .importing = self?.importState else { return }
                    self?.importState = .importing(progress: progress)
                }
            }
            importState = nil
            await load()
        } catch {
            Logger.data.error("Import failed: \(error.localizedDescription)")
            importState = .failed(message: error.localizedDescription)
        }
    }

    func delete(_ game: GameProject) async {
        do {
            try await importer.deleteGame(game)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
