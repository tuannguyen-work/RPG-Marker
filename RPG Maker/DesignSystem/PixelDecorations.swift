//
//  PixelDecorations.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Gold RPG menu cursor that nudges back and forth.
struct PixelCursor: View {
    var size: CGFloat = 12

    var body: some View {
        Image(.uiCursor)
            .resizable()
            .scaledToFit()
            .frame(width: size)
            .phaseAnimator([0, 3]) { cursor, offset in
                cursor.offset(x: offset)
            } animation: { _ in
                .easeInOut(duration: 0.45)
            }
            .accessibilityHidden(true)
    }
}

/// Gold ornamental line used between sections.
struct OrnamentDivider: View {
    var body: some View {
        Image(.uiDivider)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 200)
            .accessibilityHidden(true)
    }
}

/// Full-screen backgrounds.
struct AppBackground: View {
    enum Style {
        /// Dark night sky with a warm horizon, for the library.
        case sky
        /// Subtle tiled diamond pattern, for onboarding and around the game screen.
        case pattern
    }

    var style: Style = .sky

    var body: some View {
        ZStack {
            Theme.Colors.background
            switch style {
            case .sky:
                // Color.clear takes the proposed size; the filled image is clipped to it
                // so it never widens the layout.
                Color.clear
                    .overlay {
                        Image(.bgLibrary)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            case .pattern:
                Image(.bgPattern)
                    .resizable(resizingMode: .tile)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack {
            PixelCursor()
            Text("Continue").foregroundStyle(Theme.Colors.gold)
        }
        OrnamentDivider()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { AppBackground(style: .pattern) }
}
