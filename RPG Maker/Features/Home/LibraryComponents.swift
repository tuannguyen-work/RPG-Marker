//
//  LibraryComponents.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Cover art for a game. Until covers are captured from the title screen,
/// each game gets one of the built-in pixel-art covers, always the same one for the same game.
struct GameCover: View {
    let game: GameProject

    private static let fallbacks: [ImageResource] = [
        .coverForest, .coverCastle, .coverSea, .coverDesert,
        .coverSnow, .coverDungeon, .coverSky, .coverTown,
    ]

    /// Stable across launches (unlike `hashValue`, which is seeded per process).
    private var fallback: ImageResource {
        let sum = withUnsafeBytes(of: game.id.uuid) { $0.reduce(0) { $0 + Int($1) } }
        return Self.fallbacks[sum % Self.fallbacks.count]
    }

    var body: some View {
        Color.clear
            .overlay {
                // Covers are stored at their native low resolution; keep the pixels sharp when scaling up.
                Image(fallback)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)
    }
}

struct EngineBadge: View {
    let engine: GameEngine

    var body: some View {
        Text(engine.displayName)
            .font(Theme.Fonts.pixelLabel)
            .foregroundStyle(Theme.Colors.gold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.Colors.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Library grid item.
struct GameCard: View {
    let game: GameProject
    var isHighlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            GameCover(game: game)
                .frame(height: 104)
                .overlay(alignment: .topLeading) {
                    EngineBadge(engine: game.engine).padding(6)
                }
            Text(game.name)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Text(game.formattedPlayTime)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(12)
        .pixelFrame(isHighlighted ? .cardSelected : .card)
        .accessibilityElement(children: .combine)
    }
}

/// RPG-style "save file" panel for the most recently played game.
struct ContinueCard: View {
    let game: GameProject
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: Theme.Spacing.sm) {
                PixelCursor()
                Text("CONTINUE")
                    .font(Theme.Fonts.pixelLabel)
                    .foregroundStyle(Theme.Colors.gold)
            }

            HStack(alignment: .top, spacing: 14) {
                GameCover(game: game)
                    .frame(width: 112, height: 84)
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.name)
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    statRow("Play Time", game.formattedPlayTime)
                    statRow("Engine", game.engine.displayName)
                }
            }

            Button(action: onResume) {
                Text("Resume").frame(maxWidth: .infinity)
            }
            .buttonStyle(.pixel)
        }
        .padding(18)
        .pixelFrame(.window)
    }

    private func statRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.Colors.textPrimary)
        }
        .font(Theme.Fonts.pixelLabel)
    }
}

struct EmptyLibraryView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(.emptyLibrary)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260)
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.sm) {
                Text("Your library is empty")
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Import a game you own from the Files app to start playing.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Import Game", action: onImport)
                .buttonStyle(.pixel)
        }
        .padding(32)
    }
}
