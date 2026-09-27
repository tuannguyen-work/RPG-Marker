//
//  FileProjectRepository.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

/// Persists the library as a single JSON file. Small and simple; swap for SwiftData if it grows.
actor FileProjectRepository: ProjectRepository {
    private let fileURL: URL
    private var projects: [GameProject.ID: GameProject]?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func fetchAll() async throws -> [GameProject] {
        try loaded().values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ project: GameProject) async throws {
        var all = try loaded()
        all[project.id] = project
        try persist(all)
    }

    func delete(id: GameProject.ID) async throws {
        var all = try loaded()
        all[id] = nil
        try persist(all)
    }

    private func loaded() throws -> [GameProject.ID: GameProject] {
        if let projects { return projects }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            projects = [:]
            return [:]
        }
        let list = try JSONDecoder().decode([GameProject].self, from: Data(contentsOf: fileURL))
        let all = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        projects = all
        return all
    }

    private func persist(_ all: [GameProject.ID: GameProject]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Array(all.values)).write(to: fileURL, options: .atomic)
        projects = all
    }
}
