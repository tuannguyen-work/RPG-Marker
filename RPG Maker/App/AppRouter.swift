//
//  AppRouter.swift
//  RPG Maker
//

import SwiftUI

/// Every screen that can be pushed onto the main navigation stack.
enum Route: Hashable {
    case projectDetail(GameProject.ID)
}

@Observable
final class AppRouter {
    var path = NavigationPath()

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
