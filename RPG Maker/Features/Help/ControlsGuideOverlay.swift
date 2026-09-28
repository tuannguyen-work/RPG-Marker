//
//  ControlsGuideOverlay.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// First-play walkthrough of the on-screen controls: a callout next to each control, laid over
/// the real gamepad so the labels point at the actual buttons.
struct ControlsGuideOverlay: View {
    /// "Turbo" (MV/MZ) or "Dash" (XP/VX/VX Ace), as on the button.
    let turboTitle: LocalizedStringKey
    let turboMeaning: LocalizedStringKey
    let onDone: () -> Void

    @AppStorage(PreferenceKey.controlsSize) private var size = ControlsSize.medium
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            let layout = GamepadLayout(size: geometry.size, scale: size.scale)
            // Just around the arrow tips; the cross leaves the square's corners empty.
            let padRadius = GamepadLayout.directionPadSize * layout.scale * 0.54
            let buttonRadius = GamepadLayout.roundButtonSize * layout.scale / 2

            ZStack {
                Color.black.opacity(0.72)

                Group {
                    Highlight(radius: padRadius + 6).position(layout.dpad)
                    Highlight(radius: buttonRadius + 4).position(layout.confirm)
                    Highlight(radius: buttonRadius + 4).position(layout.cancel)
                    Highlight(radius: 30 * layout.scale, isCapsule: true).position(layout.turbo)
                    Highlight(radius: 30 * layout.scale, isCapsule: true).position(layout.menu)
                }

                Callout(title: "Move", detail: "Slide your thumb between arrows. Corners move diagonally.", alignment: .leading)
                    .position(x: layout.dpad.x + padRadius + 120, y: layout.dpad.y + 20)
                Callout(title: turboTitle, detail: turboMeaning, alignment: .leading)
                    .position(x: layout.turbo.x + 150, y: layout.turbo.y - 6)
                Callout(title: "A · Confirm", detail: "Talk, open, select.", alignment: .trailing)
                    .position(x: layout.confirm.x - buttonRadius - 205, y: layout.confirm.y - 4)
                Callout(title: "B · Cancel", detail: "Go back. In many games, opens the menu.", alignment: .trailing)
                    .position(x: layout.cancel.x - buttonRadius - 110, y: layout.cancel.y + 30)
                Callout(title: "Menu", detail: "The game's main menu.", alignment: .trailing)
                    .position(x: layout.menu.x - 150, y: layout.menu.y - 6)

                // Top middle is the one area no control or callout uses.
                VStack(spacing: 10) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "pause.fill")
                        Text("Pause any time to change speed, hide the buttons or quit.")
                    }
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 260)

                    Button("Got It", action: dismiss)
                        .buttonStyle(.pixel)
                        .frame(width: 160)
                }
                .position(x: geometry.size.width / 2, y: 72)
            }
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 1.04)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(0.2)) { isVisible = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) { isVisible = false } completion: {
            onDone()
        }
    }
}

/// Pulsing gold ring around a control.
private struct Highlight: View {
    let radius: CGFloat
    var isCapsule = false
    @State private var pulse = false

    var body: some View {
        Group {
            if isCapsule {
                Capsule().strokeBorder(Theme.Colors.gold, lineWidth: 2.5)
                    .frame(width: radius * 2.6, height: radius * 1.3)
            } else {
                Circle().strokeBorder(Theme.Colors.gold, lineWidth: 2.5)
                    .frame(width: radius * 2, height: radius * 2)
            }
        }
        .scaleEffect(pulse ? 1.06 : 0.97)
        .opacity(pulse ? 1 : 0.6)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }
}

private struct Callout: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(Theme.Fonts.pixelLabel)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.gold)
            Text(detail)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        }
        .frame(width: 180, alignment: alignment == .leading ? .leading : .trailing)
        .accessibilityElement(children: .combine)
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        AppBackground(style: .pattern)
        VirtualGamepadView { _, _ in }
        ControlsGuideOverlay(turboTitle: "Turbo", turboMeaning: "Hold to fast-forward.") {}
    }
    .ignoresSafeArea()
}
