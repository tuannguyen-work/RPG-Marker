//
//  Preferences.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

/// UserDefaults keys for user preferences (read with @AppStorage).
nonisolated enum PreferenceKey {
    static let controlsOpacity = "controls.opacity"
    static let controlsSize = "controls.size"
    static let hapticsEnabled = "haptics.enabled"
    static let librarySort = "library.sort"
    static let iCloudSaves = "saves.iCloud"
    static let hasSeenControlsGuide = "guide.controlsSeen"
}

/// Size of the on-screen controls, as a scale of the default layout.
nonisolated enum ControlsSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: Self { self }

    var scale: CGFloat {
        switch self {
        case .small: 0.85
        case .medium: 1
        case .large: 1.15
        }
    }

    var title: String {
        switch self {
        case .small: String(localized: "Small")
        case .medium: String(localized: "Medium")
        case .large: String(localized: "Large")
        }
    }
}
