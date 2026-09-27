//
//  Theme.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Shared design tokens ("Handheld Quest" style). Use these instead of hard-coded values in views.
enum Theme {
    enum Colors {
        static let background = Color(hex: 0x0F1012)
        static let surface = Color(hex: 0x1A1C20)
        static let surfaceRaised = Color(hex: 0x1F2226)
        static let navy = Color(hex: 0x1C2470)
        static let ember = Color(hex: 0xFF6B2C)
        static let gold = Color(hex: 0xFFD166)
        static let textPrimary = Color(hex: 0xF2F3F5)
        static let textSecondary = Color(hex: 0x9097A3)
    }

    enum Fonts {
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)
        static let title = Font.system(.title3, design: .rounded, weight: .bold)
        static let headline = Font.system(.headline, design: .rounded, weight: .bold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded, weight: .semibold)
        /// Short uppercase labels and numbers in RPG-style panels ("CONTINUE", "12:40").
        static let pixelLabel = Font.system(.caption, design: .monospaced, weight: .bold)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
