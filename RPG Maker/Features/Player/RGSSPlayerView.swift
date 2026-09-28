//
//  RGSSPlayerView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI
import os

/// Runs an RPG Maker XP / VX / VX Ace game in mkxp-z. SDL shows the game in its own window on top
/// of the app until the game quits; this view then records play time and returns to the library.
struct RGSSPlayerView: View {
    let game: GameProject
    let directories: AppDirectories
    let repository: any ProjectRepository

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .statusBarHidden()
            .task { await run() }
    }

    private func run() async {
        OrientationLock.set(.landscape)
        // Let the rotation finish so SDL creates its window in landscape.
        try? await Task.sleep(for: .milliseconds(400))

        var played = game
        played.lastPlayedAt = .now
        try? await repository.save(played)

        let start = Date.now
        let root = directories.contentRoot(for: game).path
        Logger.runtime.info("Starting mkxp-z for \(game.engine.displayName, privacy: .public)")
        let status = MKXPRunGame(root)
        Logger.runtime.info("mkxp-z finished with status \(status)")

        played.playTime += Date.now.timeIntervalSince(start)
        played.lastPlayedAt = .now
        played.updatedAt = .now
        try? await repository.save(played)

        OrientationLock.set(.portrait)
        dismiss()
    }
}
