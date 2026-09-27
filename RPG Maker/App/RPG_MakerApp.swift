//
//  RPG_MakerApp.swift
//  RPG Maker
//
//  Created by Admin on 9/27/26.
//

import SwiftUI

@main
struct RPG_MakerApp: App {
    @State private var dependencies = AppDependencies.live

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
        }
    }
}
