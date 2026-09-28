//
//  SaveLibrary.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

/// A game's save slots as the user sees them, plus exporting and clearing them.
///
/// MV/MZ saves are key files from `GameSaveStore` ("RPG File1.sav", "rmmzsave.<id>.file1.sav");
/// XP/VX/VX Ace saves are the game's own files ("Save01.rvdata2") kept by `RGSSSaveSync`.
nonisolated struct SaveLibrary {
    struct Slot: Identifiable, Hashable {
        let number: Int
        let modifiedAt: Date?
        var id: Int { number }
    }

    let game: GameProject
    let directories: AppDirectories

    private var directory: URL { directories.saveDirectory(for: game.id) }

    /// Numbered save slots, lowest first. Settings and the save index aren't listed.
    func slots() -> [Slot] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        var slots: [Int: Slot] = [:]
        for file in files {
            let name = (file.deletingPathExtension().lastPathComponent.removingPercentEncoding ?? "").lowercased()
            guard let number = Self.slotNumber(in: name) else { continue }
            let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            slots[number] = Slot(number: number, modifiedAt: date)
        }
        return slots.values.sorted { $0.number < $1.number }
    }

    var hasSaves: Bool {
        !((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).isEmpty
    }

    /// "file3" (MV/MZ) or "save03" (RGSS) → 3.
    private static func slotNumber(in name: String) -> Int? {
        for prefix in ["file", "save"] {
            guard let range = name.range(of: prefix, options: .backwards) else { continue }
            let digits = name[range.upperBound...].drop { $0 == " " }.prefix(while: \.isNumber)
            if let number = Int(digits), number > 0 { return number }
        }
        return nil
    }

    /// Zips the save folder into a temporary file named after the game, for the share sheet.
    func exportArchive() throws -> URL {
        var coordinatorError: NSError?
        var archive: URL?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinatorError) { zipped in
            do {
                let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let safeName = game.name.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
                let target = folder.appending(path: "\(safeName) Saves.zip")
                try FileManager.default.copyItem(at: zipped, to: target)
                archive = target
            } catch {
                copyError = error
            }
        }
        if let error = coordinatorError ?? copyError { throw error }
        guard let archive else { throw CocoaError(.fileReadUnknown) }
        return archive
    }

    enum ImportError: LocalizedError {
        case noSavesFound

        var errorDescription: String? {
            String(localized: "No save files for this game were found.")
        }
    }

    /// Copies saves into the game from a ZIP (as made by `exportArchive`, or zipped on a PC) or from
    /// loose save files. Existing slots with the same name are replaced. Returns the number of files.
    func importSaves(from sources: [URL]) throws -> Int {
        let fileManager = FileManager.default
        let scratch = fileManager.temporaryDirectory.appending(path: "SaveImport-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: scratch) }

        var candidates: [URL] = []
        for source in sources {
            let isAccessing = source.startAccessingSecurityScopedResource()
            defer { if isAccessing { source.stopAccessingSecurityScopedResource() } }
            let copy = scratch.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try fileManager.createDirectory(at: copy, withIntermediateDirectories: true)
            if source.pathExtension.lowercased() == "zip" {
                try ZipArchive(url: source).extract(to: copy)
                candidates += Self.regularFiles(in: copy)
            } else {
                let target = copy.appending(path: source.lastPathComponent)
                try fileManager.copyItem(at: source, to: target)
                candidates.append(target)
            }
        }

        let saves = candidates.filter(isSaveFile)
        guard !saves.isEmpty else { throw ImportError.noSavesFound }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        for file in saves {
            let target = directory.appending(path: file.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) { try fileManager.removeItem(at: target) }
            try fileManager.copyItem(at: file, to: target)
            // Newer than any iCloud copy, so the import wins the next sync.
            try? fileManager.setAttributes([.modificationDate: Date.now], ofItemAtPath: target.path)
        }
        return saves.count
    }

    private func isSaveFile(_ url: URL) -> Bool {
        guard !url.lastPathComponent.hasPrefix(".") else { return false }
        return game.engine.usesWebRuntime ? url.pathExtension.lowercased() == "sav" : RGSSSaveSync.isSaveFile(url)
    }

    private static func regularFiles(in directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
        return (enumerator?.allObjects as? [URL] ?? []).filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                && !$0.path.contains("__MACOSX")
        }
    }

    func removeAll() {
        if game.engine.usesWebRuntime {
            try? FileManager.default.removeItem(at: directory)
        } else {
            RGSSSaveSync(gameRoot: directories.contentRoot(for: game), saveDirectory: directory).removeAll()
        }
    }
}
