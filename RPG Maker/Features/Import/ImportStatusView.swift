//
//  ImportStatusView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Modal panel shown over the library while a game is imported, or when the import failed.
struct ImportStatusView: View {
    let state: HomeViewModel.ImportState
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                switch state {
                case .importing(let progress):
                    HStack(spacing: Theme.Spacing.sm) {
                        PixelCursor()
                        Text("IMPORTING")
                            .font(Theme.Fonts.pixelLabel)
                            .foregroundStyle(Theme.Colors.gold)
                    }
                    PixelProgressBar(value: progress)
                    Text("Extracting files and detecting the engine…")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                case .failed(let message):
                    Image(.unsupported)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 160)
                        .accessibilityHidden(true)
                    Text("Couldn't import this game")
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button(action: onDismiss) {
                        Text("OK").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pixel)
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .pixelFrame(.window)
            .padding(24)
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// Segmented RPG-style progress bar.
struct PixelProgressBar: View {
    let value: Double
    private let segments = 20

    var body: some View {
        let filled = Int((min(max(value, 0), 1) * Double(segments)).rounded(.down))
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                Rectangle()
                    .fill(index < filled ? Theme.Colors.gold : Theme.Colors.background.opacity(0.6))
            }
        }
        .frame(height: 14)
        .padding(3)
        .overlay(Rectangle().strokeBorder(Theme.Colors.textPrimary, lineWidth: 2))
        .accessibilityElement()
        .accessibilityLabel("Import progress")
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

#Preview("Importing") {
    ImportStatusView(state: .importing(progress: 0.45)) {}
        .background { AppBackground() }
}

#Preview("Failed") {
    ImportStatusView(state: .failed(message: "RPG Maker 2000 and 2003 games aren't supported yet.")) {}
        .background { AppBackground() }
}
