//
//  CloudSaves.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation
import os

/// Keeps each game's save folder in sync with the app's iCloud Drive container, so progress follows
/// the user to their other devices and survives deleting and re-importing a game.
///
///     <iCloud container>/Saves/<game key>/…   same files as <root>/Saves/<id>/
///
/// Games get a new id on every import, so the cloud folder is keyed by the game's own title
/// (plus MZ's game id) instead. Files are merged one by one and the newer copy wins; nothing is
/// deleted by a sync, only by `removeAll(for:)`.
nonisolated final class CloudSaves: Sendable {
    private let directories: AppDirectories

    init(directories: AppDirectories) {
        self.directories = directories
    }

    /// The user's choice in Settings; on by default.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: PreferenceKey.iCloudSaves) as? Bool ?? true
    }

    /// Signed in to iCloud. Cheap enough for the main thread, unlike looking up the container.
    static var isAccountAvailable: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fakeCloud") { return true }
        #endif
        return FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Sync

    /// Merges local and cloud saves for `game`. Gives up after `timeout`, leaving the copies that
    /// finished in place; the next sync picks up the rest.
    func sync(_ game: GameProject, timeout: Duration = .seconds(8)) async {
        guard Self.isEnabled, Self.isAccountAvailable else { return }
        await withTimeout(timeout) { [self] in
            self.syncNow(game)
        }
    }

    /// Deletes the game's saves from iCloud (the user deleted them in the app).
    func removeAll(for game: GameProject) {
        guard Self.isAccountAvailable, let folder = cloudFolder(for: game) else { return }
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: folder, options: .forDeleting, error: &error) { url in
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func syncNow(_ game: GameProject) {
        guard let cloud = cloudFolder(for: game) else { return }
        let local = directories.saveDirectory(for: game.id)
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: cloud, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: local, withIntermediateDirectories: true)
        } catch {
            Logger.data.error("iCloud save folder unavailable: \(error.localizedDescription)")
            return
        }

        let cloudFiles = downloadedFiles(in: cloud)
        let localFiles = Self.files(in: local)
        var pulled = 0
        var pushed = 0

        for name in Set(cloudFiles.keys).union(localFiles.keys) {
            let cloudDate = cloudFiles[name]
            let localDate = localFiles[name]
            // Tolerance: copies keep their date, but file systems round it differently.
            if let cloudDate, localDate.map({ cloudDate > $0.addingTimeInterval(1) }) ?? true {
                if coordinatedCopy(from: cloud.appending(path: name), to: local.appending(path: name), cloudSide: .source) { pulled += 1 }
            } else if let localDate, cloudDate.map({ localDate > $0.addingTimeInterval(1) }) ?? true {
                if coordinatedCopy(from: local.appending(path: name), to: cloud.appending(path: name), cloudSide: .destination) { pushed += 1 }
            }
        }
        if pulled + pushed > 0 {
            Logger.data.info("iCloud saves for \(game.name, privacy: .public): \(pulled) down, \(pushed) up")
        }
    }

    private enum CloudSide { case source, destination }

    private func coordinatedCopy(from source: URL, to destination: URL, cloudSide: CloudSide) -> Bool {
        let fileManager = FileManager.default
        var success = false
        var coordinationError: NSError?
        let copy = { (from: URL, to: URL) in
            do {
                if fileManager.fileExists(atPath: to.path) { try fileManager.removeItem(at: to) }
                try fileManager.copyItem(at: from, to: to)
                success = true
            } catch {
                Logger.data.error("iCloud save copy failed: \(error.localizedDescription)")
            }
        }
        let coordinator = NSFileCoordinator()
        switch cloudSide {
        case .source:
            coordinator.coordinate(readingItemAt: source, options: .withoutChanges, error: &coordinationError) { copy($0, destination) }
        case .destination:
            coordinator.coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { copy(source, $0) }
        }
        return success
    }

    /// Cloud files by name with their dates, after asking iCloud to download any that are only
    /// placeholders. Waits a few seconds for the downloads; files still missing are skipped.
    private func downloadedFiles(in folder: URL) -> [String: Date] {
        let fileManager = FileManager.default
        let deadline = Date.now.addingTimeInterval(6)
        while true {
            var pending = false
            let items = (try? fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey, .contentModificationDateKey]
            )) ?? []
            for item in items {
                let name = item.lastPathComponent
                // Older iOS lists placeholders as ".Name.icloud".
                if name.hasPrefix("."), name.hasSuffix(".icloud") {
                    let real = folder.appending(path: String(name.dropFirst().dropLast(".icloud".count)))
                    try? fileManager.startDownloadingUbiquitousItem(at: real)
                    pending = true
                    continue
                }
                let status = try? item.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
                if let status, status != .current {
                    try? fileManager.startDownloadingUbiquitousItem(at: item)
                    pending = true
                }
            }
            if !pending || Date.now > deadline { break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return Self.files(in: folder)
    }

    /// Regular, fully present files by name with their modification dates.
    private static func files(in folder: URL) -> [String: Date] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .ubiquitousItemDownloadingStatusKey]
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys))) ?? []
        var result: [String: Date] = [:]
        for item in items where !item.lastPathComponent.hasPrefix(".") {
            guard let values = try? item.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            if let status = values.ubiquitousItemDownloadingStatus, status != .current { continue }
            result[item.lastPathComponent] = values.contentModificationDate ?? .distantPast
        }
        return result
    }

    // MARK: - Locations

    private func cloudFolder(for game: GameProject) -> URL? {
        guard let container = Self.container() else { return nil }
        return container
            .appending(path: "Saves", directoryHint: .isDirectory)
            .appending(path: Self.key(for: game, contentRoot: directories.contentRoot(for: game)), directoryHint: .isDirectory)
    }

    /// Looks up the iCloud container. Can block, so never call it on the main thread.
    private static func container() -> URL? {
        #if DEBUG
        // `-fakeCloud`: a local folder stands in for iCloud Drive (simulators have no account).
        if ProcessInfo.processInfo.arguments.contains("-fakeCloud") {
            return URL.cachesDirectory.appending(path: "FakeCloud", directoryHint: .isDirectory)
        }
        #endif
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)
    }

    /// Same game, same key on every device: engine plus the title the game itself declares.
    static func key(for game: GameProject, contentRoot: URL) -> String {
        let resolver = CaseInsensitiveResolver(root: contentRoot)
        var parts = [game.engine.rawValue]
        if game.engine.usesWebRuntime {
            if let url = resolver.resolve("data/System.json"),
               let data = try? Data(contentsOf: url),
               let system = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                parts.append((system["gameTitle"] as? String) ?? "")
                // MZ projects have a random id, which also separates games with the same title.
                if let advanced = system["advanced"] as? [String: Any], let id = advanced["gameId"] {
                    parts.append("\(id)")
                }
            }
        } else if let url = resolver.resolve("Game.ini"), let data = try? Data(contentsOf: url) {
            let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            for line in text.split(whereSeparator: \.isNewline) {
                let pair = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces).lowercased() == "title" {
                    parts.append(String(pair[1]))
                    break
                }
            }
        }
        parts = parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if parts.count == 1 {
            // No title in the game's data: fall back to the name it was imported with.
            parts.append(game.name)
        }
        let unsafe = CharacterSet(charactersIn: "/\\:?*\"<>|").union(.controlCharacters)
        return parts.joined(separator: "-")
            .components(separatedBy: unsafe).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Runs `work` off the main thread and returns when it finishes or after `timeout`, whichever
/// comes first. The work keeps running in the background after a timeout.
nonisolated private func withTimeout(_ timeout: Duration, _ work: @escaping @Sendable () -> Void) async {
    let finished = OSAllocatedUnfairLock(initialState: false)
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        let resume = {
            let isFirst = finished.withLock { done in
                defer { done = true }
                return !done
            }
            if isFirst { continuation.resume() }
        }
        Task.detached(priority: .userInitiated) {
            work()
            resume()
        }
        Task.detached {
            try? await Task.sleep(for: timeout)
            resume()
        }
    }
}
