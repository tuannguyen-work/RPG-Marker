//
//  GameImporter.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation
import os

/// Copies or extracts a user-picked game into app storage, detects its engine and adds it to the library.
actor GameImporter {
    enum ImportError: LocalizedError, Equatable {
        case archiveFormatNotSupportedYet(String)
        case unsupportedFile
        case passwordProtected
        case damagedArchive
        case rpgMaker2000
        case noGameFound

        var errorDescription: String? {
            switch self {
            case .archiveFormatNotSupportedYet(let format):
                String(localized: "\(format.uppercased()) archives aren't supported yet. Extract it first, or import a ZIP file or a folder.")
            case .unsupportedFile:
                String(localized: "This file type isn't supported. Import a ZIP file or a folder.")
            case .passwordProtected:
                String(localized: "Password-protected archives aren't supported yet.")
            case .damagedArchive:
                String(localized: "The archive seems to be damaged or incomplete.")
            case .rpgMaker2000:
                String(localized: "RPG Maker 2000 and 2003 games aren't supported yet.")
            case .noGameFound:
                String(localized: "No RPG Maker XP, VX, VX Ace, MV or MZ game was found in this file.")
            }
        }
    }

    private let directories: AppDirectories
    private let repository: any ProjectRepository
    private var attemptedCovers = Set<GameProject.ID>()

    init(directories: AppDirectories, repository: any ProjectRepository) {
        self.directories = directories
        self.repository = repository
    }

    /// Imports a ZIP archive or a folder. `progress` receives 0...1 while extracting.
    func importGame(from source: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> GameProject {
        let isAccessing = source.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { source.stopAccessingSecurityScopedResource() }
            // When a file is shared as a copy, iOS puts it in Documents/Inbox; it's no longer needed.
            if Self.isInboxCopy(source) { try? FileManager.default.removeItem(at: source) }
        }

        try directories.prepare()
        let id = UUID()
        let staging = directories.staging.appending(path: id.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        try unpack(source, into: staging, progress: progress)

        let detection: EngineDetector.Detection
        do {
            detection = try EngineDetector.detect(in: staging)
        } catch EngineDetector.Failure.rpgMaker2000 {
            throw ImportError.rpgMaker2000
        } catch {
            throw ImportError.noGameFound
        }

        // Resolve while staging still exists: symlinks (/var → /private/var) only resolve for existing paths.
        let contentPath = Self.relativePath(of: detection.root, in: staging)
        let gameDirectory = directories.gameDirectory(for: id)
        try FileManager.default.moveItem(at: staging, to: gameDirectory)

        let game = GameProject(
            id: id,
            name: detection.title ?? source.deletingPathExtension().lastPathComponent,
            engine: detection.engine,
            contentPath: contentPath
        )
        CoverExtractor.writeCover(for: game.engine, contentRoot: directories.contentRoot(for: game), to: directories.coverFile(for: id))
        do {
            try await repository.save(game)
        } catch {
            try? FileManager.default.removeItem(at: gameDirectory)
            try? FileManager.default.removeItem(at: directories.coverFile(for: id))
            throw error
        }
        Logger.data.info("Imported \(game.engine.displayName, privacy: .public) game at \(game.contentPath, privacy: .public)")
        return game
    }

    func deleteGame(_ game: GameProject) async throws {
        try? FileManager.default.removeItem(at: directories.gameDirectory(for: game.id))
        try? FileManager.default.removeItem(at: directories.coverFile(for: game.id))
        try await repository.delete(id: game.id)
    }

    /// Creates covers for games imported before covers existed. Games without usable artwork are
    /// retried at most once per launch.
    func addMissingCovers(for games: [GameProject]) {
        for game in games where !attemptedCovers.contains(game.id) {
            attemptedCovers.insert(game.id)
            let cover = directories.coverFile(for: game.id)
            guard !FileManager.default.fileExists(atPath: cover.path) else { continue }
            CoverExtractor.writeCover(for: game.engine, contentRoot: directories.contentRoot(for: game), to: cover)
        }
    }

    // MARK: - Unpacking

    private func unpack(_ source: URL, into staging: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        let isDirectory = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            try coordinatedRead(source) { url in
                try FileManager.default.copyItem(at: url, to: staging.appending(path: url.lastPathComponent))
            }
            progress(1)
            return
        }

        switch source.pathExtension.lowercased() {
        case "zip":
            try coordinatedRead(source) { url in
                do {
                    try ZipArchive(url: url).extract(to: staging, progress: progress)
                } catch ZipArchive.Error.encrypted {
                    throw ImportError.passwordProtected
                } catch is ZipArchive.Error {
                    throw ImportError.damagedArchive
                }
            }
        case "7z", "rar":
            throw ImportError.archiveFormatNotSupportedYet(source.pathExtension)
        default:
            throw ImportError.unsupportedFile
        }
    }

    /// Reads through a file coordinator so iCloud Drive files are downloaded first.
    private func coordinatedRead(_ url: URL, _ body: (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var bodyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readableURL in
            do { try body(readableURL) } catch { bodyError = error }
        }
        if let error = bodyError ?? coordinatorError { throw error }
    }

    private static func isInboxCopy(_ url: URL) -> Bool {
        let inbox = URL.documentsDirectory.appending(path: "Inbox").resolvingSymlinksInPath().path + "/"
        return url.resolvingSymlinksInPath().path.hasPrefix(inbox)
    }

    private static func relativePath(of url: URL, in base: URL) -> String {
        let components = url.resolvingSymlinksInPath().pathComponents
        let baseComponents = base.resolvingSymlinksInPath().pathComponents
        return components.dropFirst(baseComponents.count).joined(separator: "/")
    }
}
