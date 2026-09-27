//
//  GameProject.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

struct GameProject: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.updatedAt = updatedAt
    }
}

extension GameProject {
    static let samples: [GameProject] = [
        GameProject(name: "Dragon Quest Clone"),
        GameProject(name: "Dungeon Crawler"),
    ]
}
