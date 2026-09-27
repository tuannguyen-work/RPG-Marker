//
//  PixelFrame.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Nine-slice pixel-art frames from the asset catalog.
/// Cap insets are in points (the images are @3x) and cover the border plus the rounded corners,
/// so only the flat interior is stretched.
enum PixelFrame {
    case window
    case card
    case cardSelected

    var image: ImageResource {
        switch self {
        case .window: .uiWindow
        case .card: .uiCard
        case .cardSelected: .uiCardSelected
        }
    }

    var capInsets: EdgeInsets {
        switch self {
        case .window: EdgeInsets(top: 9, leading: 9, bottom: 9, trailing: 9)
        case .card, .cardSelected: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        }
    }
}

extension View {
    /// Draws `frame` behind the view, stretched to the view's size.
    func pixelFrame(_ frame: PixelFrame) -> some View {
        background {
            Image(frame.image)
                .resizable(capInsets: frame.capInsets, resizingMode: .stretch)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        Text("Window")
            .frame(width: 280, height: 120)
            .pixelFrame(.window)
        HStack(spacing: 16) {
            Text("Card").frame(width: 140, height: 180).pixelFrame(.card)
            Text("Selected").frame(width: 140, height: 180).pixelFrame(.cardSelected)
        }
    }
    .foregroundStyle(Theme.Colors.textPrimary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background)
}
