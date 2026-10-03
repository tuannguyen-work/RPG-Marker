//
//  SplashView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Short animated intro shown over the app at launch.
///
/// It starts exactly where the static launch screen leaves off (LaunchBackground + LaunchLogo,
/// centered), so the handoff is invisible: the crystal lights up and rises, the wordmark types in,
/// a pixel bar fills, and the splash fades away. About 1.6 s; Reduce Motion gets a quick fade.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isLit = false
    @State private var isRaised = false
    @State private var revealedLetters = 0
    @State private var showsTagline = false
    @State private var progress = 0.0
    @State private var isLeaving = false

    private static let wordmark = Array("RPG DECK")
    /// Same point size as the launch screen image (LaunchLogo is 120 pt).
    private let logoSize: CGFloat = 120

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            SplashSparkles(isActive: isLit && !reduceMotion)
                .offset(y: isRaised ? -70 : 0)

            Image(.launchLogo)
                .resizable()
                .frame(width: logoSize, height: logoSize)
                .shadow(color: Theme.Colors.gold.opacity(isLit ? 0.55 : 0), radius: isLit ? 28 : 0)
                .scaleEffect(isLit ? 1.06 : 1)
                .offset(y: isRaised ? -70 : 0)

            VStack(spacing: 14) {
                HStack(spacing: 2) {
                    ForEach(Self.wordmark.indices, id: \.self) { index in
                        Text(String(Self.wordmark[index]))
                            .font(.custom("Pixelify Sans", size: 44).weight(.medium))
                            .foregroundStyle(index < 3 ? Theme.Colors.gold : Theme.Colors.textPrimary)
                            .opacity(index < revealedLetters ? 1 : 0)
                            .offset(y: index < revealedLetters ? 0 : 8)
                    }
                }
                .shadow(color: .black.opacity(0.6), radius: 0, x: 2, y: 2)

                Text("YOUR POCKET RPG CONSOLE")
                    .font(Theme.Fonts.pixelLabel)
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .opacity(showsTagline ? 1 : 0)

                PixelProgressBar(value: progress)
                    .frame(width: 160)
                    .opacity(showsTagline ? 1 : 0)
                    .padding(.top, 6)
            }
            .offset(y: 70)
        }
        .opacity(isLeaving ? 0 : 1)
        .scaleEffect(isLeaving && !reduceMotion ? 1.06 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(AppInfo.name))
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            isLit = true
            isRaised = true
            revealedLetters = Self.wordmark.count
            showsTagline = true
            progress = 1
            try? await Task.sleep(for: .milliseconds(600))
            await leave(duration: 0.25)
            return
        }

        withAnimation(.easeOut(duration: 0.45)) { isLit = true }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { isRaised = true }
        try? await Task.sleep(for: .milliseconds(200))
        for count in 1...Self.wordmark.count {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { revealedLetters = count }
            try? await Task.sleep(for: .milliseconds(45))
        }
        withAnimation(.easeOut(duration: 0.25)) { showsTagline = true }
        withAnimation(.easeInOut(duration: 0.55)) { progress = 1 }
        try? await Task.sleep(for: .milliseconds(650))
        await leave(duration: 0.35)
    }

    private func leave(duration: Double) async {
        withAnimation(.easeIn(duration: duration)) { isLeaving = true }
        try? await Task.sleep(for: .seconds(duration))
        onFinish()
    }
}

/// Gold pixel motes drifting up around the crystal.
private struct SplashSparkles: View {
    let isActive: Bool

    private struct Mote: Identifiable {
        let id: Int
        let x: CGFloat
        let size: CGFloat
        let delay: Double
        let rise: CGFloat
    }

    private let motes: [Mote] = (0..<14).map { index in
        var generator = SeededGenerator(seed: UInt64(index + 1))
        return Mote(
            id: index,
            x: CGFloat.random(in: -90...90, using: &generator),
            size: [3, 4, 6].randomElement(using: &generator)!,
            delay: Double.random(in: 0...0.5, using: &generator),
            rise: CGFloat.random(in: 60...130, using: &generator)
        )
    }

    var body: some View {
        ZStack {
            ForEach(motes) { mote in
                Rectangle()
                    .fill(Theme.Colors.gold)
                    .frame(width: mote.size, height: mote.size)
                    .offset(x: mote.x, y: isActive ? 40 - mote.rise : 50)
                    .opacity(isActive ? 0 : 0.9)
                    .animation(.easeOut(duration: 1.2).delay(mote.delay), value: isActive)
                    .opacity(isActive ? 1 : 0)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Deterministic randomness so the motes are laid out the same on every launch.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

#Preview {
    SplashView {}
}
