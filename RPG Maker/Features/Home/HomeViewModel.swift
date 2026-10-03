//
//  HomeViewModel.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation
import Observation
import os

enum LibraryFilter: Hashable, Identifiable {
    case all
    case favorites
    case engine(GameEngine)

    var id: Self { self }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .favorites: String(localized: "Favorites")
        case .engine(let engine): engine.displayName
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case recent, name, playTime, added

    var id: Self { self }

    var title: String {
        switch self {
        case .recent: String(localized: "Recently Played")
        case .name: String(localized: "Name")
        case .playTime: String(localized: "Play Time")
        case .added: String(localized: "Recently Added")
        }
    }

    var systemImage: String {
        switch self {
        case .recent: "clock"
        case .name: "textformat"
        case .playTime: "hourglass"
        case .added: "square.and.arrow.down"
        }
    }
}

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
    var toast: Toast?

    var searchText = ""
    var filter: LibraryFilter = .all
    var sort: LibrarySort = LibrarySort(rawValue: UserDefaults.standard.string(forKey: PreferenceKey.librarySort) ?? "") ?? .recent {
        didSet { UserDefaults.standard.set(sort.rawValue, forKey: PreferenceKey.librarySort) }
    }

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

    var isNarrowed: Bool {
        filter != .all || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Filters worth offering: Favorites once there is one, engines once the library mixes several.
    var availableFilters: [LibraryFilter] {
        var filters: [LibraryFilter] = [.all]
        if projects.contains(where: \.isFavorite) { filters.append(.favorites) }
        let engines = GameEngine.allCases.filter { engine in projects.contains { $0.engine == engine } }
        if engines.count > 1 { filters += engines.map(LibraryFilter.engine) }
        return filters
    }

    /// The grid's games after search, filter and sort.
    var visibleProjects: [GameProject] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return projects
            .filter { game in
                switch filter {
                case .all: true
                case .favorites: game.isFavorite
                case .engine(let engine): game.engine == engine
                }
            }
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) }
            .sorted(by: sortOrder)
    }

    private func sortOrder(_ lhs: GameProject, _ rhs: GameProject) -> Bool {
        switch sort {
        case .recent:
            let left = lhs.lastPlayedAt ?? lhs.addedAt
            let right = rhs.lastPlayedAt ?? rhs.addedAt
            return left > right
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        case .playTime:
            return lhs.playTime > rhs.playTime
        case .added:
            return lhs.addedAt > rhs.addedAt
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await repository.fetchAll()
            await importer.addMissingCovers(for: all)
            projects = all
            // A filter can outlive its last game (e.g. the only favorite was unstarred).
            if !availableFilters.contains(filter) { filter = .all }
        } catch {
            Logger.data.error("Failed to load projects: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func importGame(from url: URL) async -> GameProject? {
        importState = .importing(progress: 0)
        do {
            let game = try await importer.importGame(from: url) { progress in
                Task { @MainActor in self.updateImportProgress(progress) }
            }
            importState = nil
            await load()
            toast = .success(String(localized: "Added \(game.name)"))
            return game
        } catch {
            Logger.data.error("Import failed: \(error.localizedDescription)")
            importState = .failed(message: error.localizedDescription)
            return nil
        }
    }

    private func updateImportProgress(_ progress: Double) {
        guard case .importing = importState else { return }
        importState = .importing(progress: progress)
    }

    func toggleFavorite(_ game: GameProject) async {
        var updated = game
        updated.isFavorite.toggle()
        await update(updated)
    }

    func rename(_ game: GameProject, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != game.name else { return }
        var updated = game
        updated.name = trimmed
        await update(updated)
    }

    /// Saves `game` and applies it in place, so the grid animates just that card.
    private func update(_ game: GameProject) async {
        do {
            try await repository.save(game)
            if let index = projects.firstIndex(where: { $0.id == game.id }) {
                projects[index] = game
            }
            if !availableFilters.contains(filter) { filter = .all }
        } catch {
            toast = .error(error.localizedDescription)
        }
    }

    func delete(_ game: GameProject) async {
        do {
            try await importer.deleteGame(game)
            await load()
            toast = .info(String(localized: "Deleted \(game.name)"))
        } catch {
            toast = .error(error.localizedDescription)
        }
    }
}
