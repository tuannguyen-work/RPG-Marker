//
//  PlayerViewModel.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation
import Observation
import os

@Observable
final class PlayerViewModel {
    private(set) var game: GameProject
    private(set) var session: WebGameSession?
    private(set) var errorMessage: String?
    private(set) var speed = 1
    var isPaused = false {
        didSet { session?.setPaused(isPaused) }
    }
    var showsControls = true
    /// The game's own resolution, reported by the engine after it boots.
    private(set) var gameSize: CGSize?

    private let directories: AppDirectories
    private let repository: any ProjectRepository
    /// Start of the current foreground stretch; nil while in the background or stopped.
    private var activeSince: Date?
    private var playedThisSession: TimeInterval = 0

    init(game: GameProject, directories: AppDirectories, repository: any ProjectRepository) {
        self.game = game
        self.directories = directories
        self.repository = repository
    }

    func start() async {
        guard session == nil else { return }
        do {
            let store = GameSaveStore(directory: directories.saveDirectory(for: game.id))
            let session = try await WebGameSession.make(contentRoot: directories.contentRoot(for: game), engine: game.engine, saveStore: store)
            session.onScreenSize = { [weak self] size in self?.gameSize = size }
            self.session = session
            activeSince = .now
            game.lastPlayedAt = .now
            try? await repository.save(game)
        } catch {
            Logger.runtime.error("Could not start game: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Records play time and makes sure every save reached the disk.
    func stop() async {
        await recordProgress()
        session?.tearDown()
        session = nil
    }

    /// Flushes saves and adds the play time so far to the library, so nothing is lost
    /// if the app is closed while in the background.
    private func recordProgress() async {
        pauseClock()
        guard let session else { return }
        await session.flushSaves()
        game.playTime += playedThisSession
        playedThisSession = 0
        game.lastPlayedAt = .now
        game.updatedAt = .now
        try? await repository.save(game)
    }

    func handle(_ button: GamepadButton, isPressed: Bool) {
        if button == .turbo {
            if isPressed { toggleSpeed() }
            return
        }
        session?.send(button, isPressed: isPressed)
    }

    func toggleSpeed() {
        speed = speed == 1 ? 3 : 1
        session?.setSpeed(speed)
    }

    // MARK: - Play time

    func appDidBecomeActive() {
        if session != nil, activeSince == nil { activeSince = .now }
    }

    func appWillResignActive() {
        Task { await recordProgress() }
    }

    private func pauseClock() {
        if let activeSince {
            playedThisSession += Date.now.timeIntervalSince(activeSince)
        }
        activeSince = nil
    }
}
