//
//  GameProject.swift
//  RPG Maker
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
