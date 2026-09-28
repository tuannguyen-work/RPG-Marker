//
//  GuideDiagrams.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

// Small animated mock-ups used by the guide. They are drawn in code rather than as images so they
// always match the app's real screens and stay sharp at any size.

// MARK: - Building blocks

/// A simplified phone outline that hosts a mock screen.
struct MiniPhone<Content: View>: View {
    var isLandscape = false
    @ViewBuilder let content: Content

    private var size: CGSize { isLandscape ? CGSize(width: 300, height: 150) : CGSize(width: 156, height: 300) }

    var body: some View {
        content
            .frame(width: size.width - 14, height: size.height - 14)
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(7)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.Colors.textSecondary.opacity(0.6), lineWidth: 2))
            .overlay(alignment: isLandscape ? .leading : .top) {
                Capsule()
                    .fill(Color.black)
                    .frame(width: isLandscape ? 10 : 44, height: isLandscape ? 44 : 10)
                    .padding(isLandscape ? .leading : .top, 11)
            }
            .accessibilityHidden(true)
    }
}

/// Pointing hand that marks where to tap.
struct TapHint: View {
    var body: some View {
        Image(.uiHandPointer)
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
    }
}

/// Soft pulsing ring behind something tappable.
private struct PulseRing: View {
    var size: CGFloat = 30
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .stroke(Theme.Colors.gold, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(isExpanded ? 1.5 : 0.9)
            .opacity(isExpanded ? 0 : 0.9)
            .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: isExpanded)
            .onAppear { isExpanded = true }
    }
}

private struct MockCard: View {
    let cover: ImageResource
    var title: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(cover)
                .interpolation(.none)
                .resizable()
                .scaledToFill()
                .frame(height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.Colors.textPrimary.opacity(0.8))
                .frame(width: 34, height: 4)
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.Colors.textSecondary.opacity(0.6))
                .frame(width: 20, height: 3)
        }
        .padding(5)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.Colors.textSecondary.opacity(0.3), lineWidth: 1))
    }
}

private struct MockLibraryBar: View {
    var highlightsPlus = false

    var body: some View {
        HStack {
            Text("Library")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            ZStack {
                if highlightsPlus { PulseRing(size: 22) }
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                    .frame(width: 22, height: 22)
                    .background(Theme.Colors.surfaceRaised, in: Circle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 22)
    }
}

// MARK: - Import

/// Step 1: a ZIP holds the game folder.
struct ZipContentsDiagram: View {
    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: "doc.zipper")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Colors.gold)
                Text("MyGame.zip")
                    .font(Theme.Fonts.pixelLabel)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Image(systemName: "arrow.right")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
            VStack(alignment: .leading, spacing: 5) {
                FileRow(name: "MyGame", isFolder: true, depth: 0)
                FileRow(name: "Game.exe", depth: 1)
                FileRow(name: "www / Data", isFolder: true, depth: 1)
                FileRow(name: "Audio, Graphics…", isFolder: true, depth: 1)
            }
            .padding(10)
            .background(Theme.Colors.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityHidden(true)
    }
}

struct FileRow: View {
    let name: String
    var isFolder = false
    var depth = 0
    var isHighlighted = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isFolder ? "folder.fill" : "doc")
                .font(.system(size: 11))
                .foregroundStyle(isFolder ? Theme.Colors.gold : Theme.Colors.textSecondary)
            Text(name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(isHighlighted ? Theme.Colors.gold : Theme.Colors.textPrimary)
        }
        .padding(.leading, CGFloat(depth) * 14)
    }
}

/// Step 2: the ZIP saved in a folder on the device.
struct FilesDiagram: View {
    var body: some View {
        MiniPhone {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Downloads")
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.ember)
                .padding(.top, 24)

                ForEach(["Photos Backup", "Notes"], id: \.self) { name in
                    row(icon: "folder.fill", name: name, tint: Theme.Colors.textSecondary)
                }
                row(icon: "doc.zipper", name: "MyGame.zip", tint: Theme.Colors.gold)
                    .padding(4)
                    .background(Theme.Colors.gold.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(alignment: .trailing) {
                        TapHint().offset(x: 4, y: 20)
                    }
                Spacer()
            }
            .padding(.horizontal, 10)
        }
    }

    private func row(icon: String, name: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(name).foregroundStyle(Theme.Colors.textPrimary)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
    }
}

/// Step 3: tap +, pick the file, wait for the import, and the game appears.
struct ImportFlowDiagram: View {
    private enum Phase: CaseIterable { case tapPlus, pickFile, importing, done }

    var body: some View {
        PhaseAnimator(Phase.allCases) { phase in
            MiniPhone {
                ZStack(alignment: .top) {
                    VStack(spacing: 10) {
                        MockLibraryBar(highlightsPlus: phase == .tapPlus)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible())], spacing: 6) {
                            MockCard(cover: .coverCastle)
                            MockCard(cover: .coverSea)
                            if phase == .done {
                                MockCard(cover: .coverForest)
                                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.Colors.gold, lineWidth: 2))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 10)
                        Spacer()
                    }

                    if phase == .pickFile {
                        pickerSheet.transition(.move(edge: .bottom))
                    }
                    if phase == .importing {
                        progressPanel.transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if phase == .tapPlus {
                    TapHint().offset(x: -4, y: 46)
                        .transition(.opacity)
                }
            }
        } animation: { phase in
            // Each step stays on screen long enough to read.
            .spring(response: 0.5, dampingFraction: 0.85).delay(phase == .tapPlus ? 1.6 : 1.4)
        }
        .frame(height: 300)
    }

    private var pickerSheet: some View {
        VStack(alignment: .leading, spacing: 9) {
            Capsule().fill(Theme.Colors.textSecondary.opacity(0.5)).frame(width: 30, height: 4)
                .frame(maxWidth: .infinity)
            Text("Downloads")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            HStack(spacing: 6) {
                Image(systemName: "doc.zipper").foregroundStyle(Theme.Colors.gold)
                Text("MyGame.zip").foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Colors.ember)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(6)
            .background(Theme.Colors.gold.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
        .padding(.top, 110)
    }

    private var progressPanel: some View {
        VStack(spacing: 8) {
            Text("IMPORTING")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.Colors.gold)
            PixelProgressBar(value: 0.7)
                .frame(width: 100)
        }
        .padding(12)
        .background(Theme.Colors.navy, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.gold, lineWidth: 1.5))
        .padding(.top, 110)
    }
}

/// Step 4: tap the card and the game opens in landscape.
struct PlayDiagram: View {
    var body: some View {
        PhaseAnimator([false, true]) { isPlaying in
            MiniPhone(isLandscape: isPlaying) {
                if isPlaying {
                    ZStack {
                        Image(.coverForest)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 180)
                            .clipped()
                        HStack {
                            Image(systemName: "dpad.fill").font(.system(size: 26))
                            Spacer()
                            HStack(spacing: 4) {
                                Circle().frame(width: 16).offset(y: 6)
                                Circle().frame(width: 16)
                            }
                        }
                        .foregroundStyle(Theme.Colors.textPrimary.opacity(0.85))
                        .padding(.horizontal, 22)
                    }
                } else {
                    VStack(spacing: 10) {
                        MockLibraryBar()
                        MockCard(cover: .coverForest)
                            .frame(width: 90)
                            .overlay(alignment: .bottomTrailing) { TapHint().offset(x: 14, y: 14) }
                        Spacer()
                    }
                }
            }
            .frame(width: 300, height: 300)
        } animation: { _ in
            .spring(response: 0.6, dampingFraction: 0.8).delay(1.6)
        }
    }
}

// MARK: - Engines

/// The files that give each engine away.
struct EngineFilesDiagram: View {
    private let rows: [(engine: GameEngine, hints: [String])] = [
        (.mz, ["js/rmmz_core.js", "data/System.json"]),
        (.mv, ["www/js/rpg_core.js", "www/data/System.json"]),
        (.vxAce, ["Game.rgss3a", "or Data/*.rvdata2"]),
        (.vx, ["Game.rgss2a", "or Data/*.rvdata"]),
        (.xp, ["Game.rgssad", "or Data/*.rxdata"]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows, id: \.engine) { row in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    EngineBadge(engine: row.engine)
                        .frame(width: 64, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(row.hints, id: \.self) { hint in
                            Text(hint)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.gold)
                }
                .accessibilityElement(children: .combine)
            }
            Divider().overlay(Theme.Colors.textSecondary.opacity(0.3))
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("2000/2003")
                    .font(Theme.Fonts.pixelLabel)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 64, alignment: .leading)
                Text("RPG_RT.exe")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.Colors.ember)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("RPG Maker 2000 and 2003, with RPG_RT.exe: not supported")
        }
    }
}

// MARK: - Controls

/// Landscape phone with numbered markers on each control; the legend is listed below it.
struct ControlsDiagram: View {
    var body: some View {
        MiniPhone(isLandscape: true) {
            ZStack {
                Image(.coverTown)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 170)
                    .clipped()
                    .opacity(0.9)

                HStack {
                    VStack(spacing: 8) {
                        marker(2, Capsule().frame(width: 30, height: 12))
                        marker(1, Image(systemName: "dpad.fill").font(.system(size: 40)))
                    }
                    Spacer()
                    ZStack {
                        marker(5, Capsule().frame(width: 30, height: 12)).offset(x: -18, y: -40)
                        marker(3, Circle().frame(width: 26)).offset(x: 10, y: -4)
                        marker(4, Circle().frame(width: 26)).offset(x: -20, y: 20)
                    }
                    .frame(width: 70, height: 100)
                }
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.top, 14)

                Image(systemName: "pause.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(4)
                    .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 3))
                    .overlay(alignment: .topTrailing) { badge(6).offset(x: 12, y: -4) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 22)
                    .padding(.top, 6)
            }
        }
    }

    private func marker(_ number: Int, _ shape: some View) -> some View {
        shape.overlay(alignment: .topTrailing) { badge(number).offset(x: 8, y: -8) }
    }

    private func badge(_ number: Int) -> some View {
        Text("\(number)")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.Colors.background)
            .frame(width: 15, height: 15)
            .background(Theme.Colors.gold, in: Circle())
    }
}

// MARK: - Saves

/// A save travelling from one device through iCloud to another.
struct SaveSyncDiagram: View {
    private enum Phase: CaseIterable { case onPhone, inCloud, onTablet }

    var body: some View {
        PhaseAnimator(Phase.allCases) { phase in
            ZStack {
                HStack(alignment: .bottom) {
                    device(width: 58, height: 104, isActive: phase == .onPhone)
                    Spacer()
                    device(width: 96, height: 124, isActive: phase == .onTablet)
                }
                Image(systemName: "icloud.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(phase == .inCloud ? Theme.Colors.gold : Theme.Colors.textSecondary.opacity(0.7))
                    .frame(maxHeight: .infinity, alignment: .top)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Colors.gold)
                    .shadow(color: Theme.Colors.gold, radius: 6)
                    .offset(crystalOffset(phase))
            }
            .frame(width: 280, height: 170)
        } animation: { _ in
            .spring(response: 0.8, dampingFraction: 0.8).delay(1.0)
        }
        .accessibilityHidden(true)
    }

    private func crystalOffset(_ phase: Phase) -> CGSize {
        switch phase {
        case .onPhone: CGSize(width: -111, height: 30)
        case .inCloud: CGSize(width: 0, height: -58)
        case .onTablet: CGSize(width: 92, height: 22)
        }
    }

    private func device(width: CGFloat, height: CGFloat, isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Theme.Colors.background)
            .frame(width: width, height: height)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isActive ? Theme.Colors.gold : Theme.Colors.textSecondary.opacity(0.6), lineWidth: 2))
    }
}
