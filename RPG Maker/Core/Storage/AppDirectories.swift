//
//  AppDirectories.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

/// On-disk layout:
///
///     <root>/library.json        library metadata
///     <root>/Games/<id>/…        imported game files (excluded from iCloud backup: large, re-importable)
///     <root>/Saves/<id>/…        save data, one file per key (backed up)
///     <root>/Staging/<id>/…      in-progress imports, moved into Games/ when complete
nonisolated struct AppDirectories: Sendable {
    let root: URL

    var games: URL { root.appending(path: "Games", directoryHint: .isDirectory) }
    var saves: URL { root.appending(path: "Saves", directoryHint: .isDirectory) }
    var staging: URL { root.appending(path: "Staging", directoryHint: .isDirectory) }
    var libraryFile: URL { root.appending(path: "library.json", directoryHint: .notDirectory) }

    func gameDirectory(for id: UUID) -> URL {
        games.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    func saveDirectory(for id: UUID) -> URL {
        saves.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    /// The folder the runtime loads for `game`.
    func contentRoot(for game: GameProject) -> URL {
        let directory = gameDirectory(for: game.id)
        return game.contentPath.isEmpty ? directory : directory.appending(path: game.contentPath, directoryHint: .isDirectory)
    }

    /// Creates the folders and removes leftovers from interrupted imports.
    func prepare() throws {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: staging)
        for folder in [root, games, staging] {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        var games = games
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try games.setResourceValues(values)
    }

    static let live = AppDirectories(root: URL.applicationSupportDirectory)

    static func temporary() -> AppDirectories {
        AppDirectories(root: FileManager.default.temporaryDirectory.appending(path: "Library-\(UUID().uuidString)"))
    }
}
