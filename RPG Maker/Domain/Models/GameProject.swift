//
//  GameProject.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

nonisolated enum GameEngine: String, Codable, Sendable, CaseIterable {
    case xp
    case vx
    case vxAce
    case mv
    case mz

    var displayName: String {
        switch self {
        case .xp: "XP"
        case .vx: "VX"
        case .vxAce: "VX Ace"
        case .mv: "MV"
        case .mz: "MZ"
        }
    }

    /// MV and MZ run in the web runtime; XP/VX/VX Ace in mkxp-z, when this build includes it.
    var isPlayable: Bool {
        usesWebRuntime || MKXPIsAvailable()
    }

    var usesWebRuntime: Bool {
        self == .mv || self == .mz
    }
}

nonisolated struct GameProject: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var engine: GameEngine
    /// Folder the runtime loads, relative to the game's storage directory (e.g. "MyGame/www").
    var contentPath: String
    var playTime: TimeInterval
    var lastPlayedAt: Date?
    var updatedAt: Date
    var isFavorite: Bool
    /// When the game was added to the library.
    var addedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        engine: GameEngine,
        contentPath: String = "",
        playTime: TimeInterval = 0,
        lastPlayedAt: Date? = nil,
        updatedAt: Date = .now,
        isFavorite: Bool = false,
        addedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.engine = engine
        self.contentPath = contentPath
        self.playTime = playTime
        self.lastPlayedAt = lastPlayedAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.addedAt = addedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, engine, contentPath, playTime, lastPlayedAt, updatedAt, isFavorite, addedAt
    }

    /// Libraries saved by older versions lack the newer fields; they get defaults.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        engine = try container.decode(GameEngine.self, forKey: .engine)
        contentPath = try container.decodeIfPresent(String.self, forKey: .contentPath) ?? ""
        playTime = try container.decodeIfPresent(TimeInterval.self, forKey: .playTime) ?? 0
        lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? updatedAt
    }

    /// "12h 40m", or "New" before the first session.
    var formattedPlayTime: String {
        guard playTime > 0 else { return String(localized: "New") }
        return Duration.seconds(playTime).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}

extension GameProject {
    static let samples: [GameProject] = [
        GameProject(name: "Ashen Crown", engine: .mz, playTime: 45_600, lastPlayedAt: .now.addingTimeInterval(-7_200), isFavorite: true),
        GameProject(name: "Tidebound", engine: .mv, playTime: 11_100, lastPlayedAt: .now.addingTimeInterval(-86_400)),
        GameProject(name: "Hollow Lantern", engine: .vxAce, playTime: 97_920),
        GameProject(name: "Star Ferry", engine: .xp, playTime: 2_880),
    ]
}
