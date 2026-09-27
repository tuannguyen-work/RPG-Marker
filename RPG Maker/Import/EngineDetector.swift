//
//  EngineDetector.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

/// Finds the RPG Maker game inside an extracted folder and tells which engine it uses.
///
/// Games are often wrapped in one or more folders ("MyGame/www/..."), so directories are searched
/// breadth-first and the shallowest match wins. File names are compared case-insensitively
/// because archives made on Windows use any casing ("Data", "data", "GAME.INI").
nonisolated enum EngineDetector {
    struct Detection: Equatable {
        let engine: GameEngine
        /// The folder the runtime should load (e.g. the `www` folder for MV).
        let root: URL
        /// Title from System.json (MV/MZ) or Game.ini (XP/VX/VX Ace), if present.
        let title: String?
    }

    enum Failure: Error, Equatable {
        /// RPG Maker 2000/2003 (RPG_RT.ldb): not supported yet.
        case rpgMaker2000
        case notFound
    }

    static func detect(in directory: URL, maxDepth: Int = 4) throws -> Detection {
        var queue: [(url: URL, depth: Int)] = [(directory, 0)]
        var sawRPGMaker2000 = false

        while !queue.isEmpty {
            let (folder, depth) = queue.removeFirst()
            let children = listing(of: folder)

            if let engine = engine(in: children) {
                return Detection(engine: engine, root: folder, title: title(for: engine, in: children))
            }
            if children["rpg_rt.ldb"] != nil {
                sawRPGMaker2000 = true
            }
            if depth < maxDepth {
                for child in children.values.sorted(by: { $0.path < $1.path })
                where isDirectory(child) && child.lastPathComponent != "__MACOSX" {
                    queue.append((child, depth + 1))
                }
            }
        }
        throw sawRPGMaker2000 ? Failure.rpgMaker2000 : Failure.notFound
    }

    // MARK: - Engine markers

    private static func engine(in children: [String: URL]) -> GameEngine? {
        if let js = children["js"].map(listing(of:)) {
            if js["rmmz_core.js"] != nil { return .mz }
            if js["rpg_core.js"] != nil { return .mv }
        }
        // Encrypted archive or project file, then the data files themselves.
        if children["game.rgss3a"] != nil || children["game.rvproj2"] != nil { return .vxAce }
        if children["game.rgss2a"] != nil || children["game.rvproj"] != nil { return .vx }
        if children["game.rgssad"] != nil || children["game.rxproj"] != nil { return .xp }
        if let data = children["data"].map(listing(of:)) {
            let extensions = Set(data.keys.map { ($0 as NSString).pathExtension })
            if extensions.contains("rvdata2") { return .vxAce }
            if extensions.contains("rvdata") { return .vx }
            if extensions.contains("rxdata") { return .xp }
        }
        return nil
    }

    // MARK: - Title

    private static func title(for engine: GameEngine, in children: [String: URL]) -> String? {
        switch engine {
        case .mv, .mz:
            guard let system = children["data"].flatMap({ listing(of: $0)["system.json"] }),
                  let data = try? Data(contentsOf: system),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let title = json["gameTitle"] as? String else { return nil }
            return nonEmpty(title)
        case .xp, .vx, .vxAce:
            guard let ini = children["game.ini"], let data = try? Data(contentsOf: ini),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) else { return nil }
            for line in text.components(separatedBy: .newlines) {
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "title" {
                    return nonEmpty(String(parts[1]))
                }
            }
            return nil
        }
    }

    // MARK: - Helpers

    /// Lower-cased file name → URL for the folder's non-hidden children.
    private static func listing(of folder: URL) -> [String: URL] {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return Dictionary(children.map { ($0.lastPathComponent.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private static func nonEmpty(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
