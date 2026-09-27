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
            session = try await WebGameSession.make(contentRoot: directories.contentRoot(for: game), saveStore: store)
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
        pauseClock()
        guard let session else { return }
        await session.flushSaves()
        session.tearDown()
        self.session = nil
        game.playTime += playedThisSession
        game.lastPlayedAt = .now
        game.updatedAt = .now
        playedThisSession = 0
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
        pauseClock()
    }

    private func pauseClock() {
        if let activeSince {
            playedThisSession += Date.now.timeIntervalSince(activeSince)
        }
        activeSince = nil
    }
}
