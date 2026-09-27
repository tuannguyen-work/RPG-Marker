//
//  HomeViewModel.swift
//  RPG Maker
//

import Foundation
import Observation
import os

@Observable
final class HomeViewModel {
    private(set) var projects: [GameProject] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let repository: any ProjectRepository

    init(repository: any ProjectRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await repository.fetchAll()
        } catch {
            Logger.data.error("Failed to load projects: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func createProject() async {
        let project = GameProject(name: "New Project \(projects.count + 1)")
        do {
            try await repository.save(project)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
