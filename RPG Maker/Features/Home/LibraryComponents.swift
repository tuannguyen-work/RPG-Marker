//
//  LibraryComponents.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Cover art for a game: its own title screen when one was found at import,
/// otherwise one of the built-in pixel-art covers (always the same one for the same game).
struct GameCover: View {
    let game: GameProject
    @Environment(AppDependencies.self) private var dependencies
    @State private var artwork: UIImage?

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
                if let artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Built-in covers are stored at their native low resolution; keep the pixels sharp.
                    Image(fallback)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)
            .task(id: game.id) {
                artwork = UIImage(contentsOfFile: dependencies.directories.coverFile(for: game.id).path)
            }
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
                .overlay(alignment: .topTrailing) {
                    if game.isFavorite {
                        FavoriteMark()
                            .padding(6)
                            .transition(.scale(scale: 0.2).combined(with: .opacity))
                    }
                }
            Text(game.name)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .padding(.trailing, 28) // room for the "more" button laid over the card
            Text(game.formattedPlayTime)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(12)
        .pixelFrame(isHighlighted ? .cardSelected : .card)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: game.isFavorite)
        .accessibilityElement(children: .combine)
        .accessibilityValue(game.isFavorite ? Text("Favorite") : Text(""))
    }
}

/// Gold star badge on a favorite game's cover.
struct FavoriteMark: View {
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.Colors.gold)
            .padding(5)
            .background(Theme.Colors.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Horizontal chips above the grid; the selection slides between them.
struct LibraryFilterBar: View {
    let filters: [LibraryFilter]
    @Binding var selection: LibraryFilter
    @Namespace private var namespace

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(filters) { filter in
                    let isSelected = filter == selection
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = filter }
                    } label: {
                        HStack(spacing: 4) {
                            if filter == .favorites {
                                Image(systemName: "star.fill").font(.system(size: 10, weight: .bold))
                            }
                            Text(filter.title)
                        }
                        .font(Theme.Fonts.pixelLabel)
                        .textCase(.uppercase)
                        .foregroundStyle(isSelected ? Theme.Colors.background : Theme.Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Theme.Colors.gold)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Theme.Colors.textSecondary.opacity(0.5), lineWidth: 1.5)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
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
