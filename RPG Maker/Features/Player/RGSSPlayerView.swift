//
//  RGSSPlayerView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI
import os

/// Runs an RPG Maker XP / VX / VX Ace game in mkxp-z. SDL shows the game in its own window on top
/// of the app, with RGSSOverlayView laid over it, until the game quits; this view then records play
/// time and returns to the library.
struct RGSSPlayerView: View {
    let game: GameProject
    let directories: AppDirectories
    let repository: any ProjectRepository

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: RGSSSession?

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .statusBarHidden()
            .task { await run() }
            .onChange(of: scenePhase) { _, phase in
                guard let session else { return }
                if phase == .active {
                    session.appDidBecomeActive()
                } else {
                    session.appWillResignActive()
                    saves.collect()
                }
            }
    }

    private var saves: RGSSSaveSync {
        RGSSSaveSync(gameRoot: directories.contentRoot(for: game), saveDirectory: directories.saveDirectory(for: game.id))
    }

    private func run() async {
        OrientationLock.set(.landscape)
        // Let the rotation finish so SDL creates its window in landscape.
        try? await Task.sleep(for: .milliseconds(400))

        var played = game
        played.lastPlayedAt = .now
        try? await repository.save(played)
        saves.restore()

        let session = RGSSSession(title: game.name)
        self.session = session
        MKXPSetOverlayProvider {
            let overlay = UIHostingController(rootView: RGSSOverlayView(session: session))
            overlay.view.backgroundColor = .clear
            return overlay
        }

        let start = Date.now
        Logger.runtime.info("Starting mkxp-z for \(game.engine.displayName, privacy: .public)")
        let status = await withCheckedContinuation { continuation in
            MKXPStartGame(directories.contentRoot(for: game).path) { continuation.resume(returning: $0) }
        }
        Logger.runtime.info("mkxp-z finished with status \(status)")

        saves.collect()
        played.playTime += Date.now.timeIntervalSince(start)
        played.lastPlayedAt = .now
        played.updatedAt = .now
        try? await repository.save(played)

        self.session = nil
        OrientationLock.set(.portrait)
        dismiss()
    }
}

/// RGSS games write their saves (Save01.rvdata2, Save1.rxdata, …) next to Game.ini, inside the game
/// folder, which is excluded from backups and removed with the game. They are kept in Saves/<id>
/// and copied in before playing and back out afterwards.
struct RGSSSaveSync {
    let gameRoot: URL
    let saveDirectory: URL

    private static let saveExtensions: Set<String> = ["rxdata", "rvdata", "rvdata2"]

    func restore() {
        copy(from: saveDirectory, to: gameRoot) { _ in true }
    }

    func collect() {
        copy(from: gameRoot, to: saveDirectory) { url in
            url.lastPathComponent.lowercased().hasPrefix("save")
                && Self.saveExtensions.contains(url.pathExtension.lowercased())
        }
    }

    private func copy(from source: URL, to destination: URL, where include: (URL) -> Bool) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isRegularFileKey]) else { return }
        for file in files where include(file) && (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            do {
                try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                let target = destination.appending(path: file.lastPathComponent)
                if fileManager.fileExists(atPath: target.path) { try fileManager.removeItem(at: target) }
                try fileManager.copyItem(at: file, to: target)
            } catch {
                Logger.runtime.error("Save sync failed for \(file.lastPathComponent, privacy: .public): \(error.localizedDescription)")
            }
        }
    }
}
