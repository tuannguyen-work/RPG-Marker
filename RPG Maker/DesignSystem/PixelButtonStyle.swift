//
//  PixelButtonStyle.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Pixel-art button backed by nine-slice images. The label stays text so it can be localized.
struct PixelButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        configuration.label
            .font(Theme.Fonts.headline)
            .foregroundStyle(kind == .primary ? Theme.Colors.background : Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(minHeight: 48)
            .offset(y: isPressed ? 2 : 0)
            .background {
                background(isPressed: isPressed)
            }
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        switch kind {
        case .primary where isPressed:
            Image(.uiButtonPrimaryPressed)
                .resizable(capInsets: EdgeInsets(top: 17, leading: 14, bottom: 17, trailing: 14), resizingMode: .stretch)
        case .primary:
            Image(.uiButtonPrimary)
                .resizable(capInsets: EdgeInsets(top: 19, leading: 14, bottom: 19, trailing: 14), resizingMode: .stretch)
        case .secondary:
            Image(.uiButtonSecondary)
                .resizable(capInsets: EdgeInsets(top: 17, leading: 14, bottom: 17, trailing: 14), resizingMode: .stretch)
                .opacity(isPressed ? 0.75 : 1)
        }
    }
}

extension ButtonStyle where Self == PixelButtonStyle {
    static var pixel: PixelButtonStyle { PixelButtonStyle(kind: .primary) }
    static var pixelSecondary: PixelButtonStyle { PixelButtonStyle(kind: .secondary) }
}

#Preview {
    VStack(spacing: 20) {
        Button("Resume") {}
            .buttonStyle(.pixel)
        Button {
        } label: {
            Text("Import Game").frame(maxWidth: .infinity)
        }
        .buttonStyle(.pixel)
        Button("Settings") {}
            .buttonStyle(.pixelSecondary)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background)
}
