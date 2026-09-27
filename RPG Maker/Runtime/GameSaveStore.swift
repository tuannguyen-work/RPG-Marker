//
//  GameSaveStore.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

/// Key-value storage behind a game's localStorage / localforage, one file per key.
/// Lives outside the game folder so saves survive re-imports and are included in backups.
actor GameSaveStore {
    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func loadAll() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [:] }
        var result: [String: String] = [:]
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where file.pathExtension == "sav" {
            guard let key = file.deletingPathExtension().lastPathComponent.removingPercentEncoding,
                  let value = try? String(contentsOf: file, encoding: .utf8) else { continue }
            result[key] = value
        }
        return result
    }

    func set(_ value: String, for key: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(value.utf8).write(to: fileURL(for: key), options: .atomic)
    }

    func remove(_ key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    private func fileURL(for key: String) -> URL {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_. "))
        let name = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? UUID().uuidString
        return directory.appending(path: name + ".sav", directoryHint: .notDirectory)
    }
}
