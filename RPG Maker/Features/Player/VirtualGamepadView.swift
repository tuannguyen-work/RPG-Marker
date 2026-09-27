//
//  VirtualGamepadView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

enum GamepadButton: Hashable, Sendable {
    case up, down, left, right
    case confirm, cancel
    case menu, turbo
}

/// On-screen controller overlay. Reports every press and release through `onChange`.
///
/// Laid out around where thumbs rest when holding a phone sideways: a little below the middle,
/// a thumb's width in from each edge. Everything fits in the side bars next to a 4:3 game.
struct VirtualGamepadView: View {
    var onChange: (GamepadButton, _ isPressed: Bool) -> Void

    /// From the screen edge; clears the Dynamic Island, which can be on either side.
    private let edgeInset: CGFloat = 44
    /// Thumb resting height, as a fraction of the screen height.
    private let thumbLine: CGFloat = 0.62

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let thumbY = geometry.size.height * thumbLine

            // Left thumb: D-pad on the resting point, the rarely used Turbo above it.
            let dpadX = edgeInset + DPadView.size / 2
            DPadView(onChange: onChange)
                .position(x: dpadX, y: thumbY)
            SmallPadButton(title: "Turbo", button: .turbo, onChange: onChange)
                .position(x: dpadX, y: thumbY - DPadView.size / 2 - 34)

            // Right thumb: A (used most) on the resting point, B down and inward like a SNES pad,
            // Menu above within a short stretch.
            let aX = width - edgeInset - RoundPadButton.size / 2
            RoundPadButton(title: "A", button: .confirm, onChange: onChange)
                .position(x: aX, y: thumbY - 12)
            RoundPadButton(title: "B", button: .cancel, onChange: onChange)
                .position(x: aX - 66, y: thumbY + 38)
            SmallPadButton(title: "Menu", button: .menu, onChange: onChange)
                .position(x: aX - 40, y: thumbY - 78)
        }
        .opacity(0.9)
    }
}

private struct DPadView: View {
    let onChange: (GamepadButton, Bool) -> Void

    @State private var pressed: Set<GamepadButton> = []
    static let size: CGFloat = 124
    /// Touches this far outside the drawn pad still count, so a drifting thumb keeps control.
    private static let slack: CGFloat = 16
    private let deadZone: CGFloat = 14
    private var hitSize: CGFloat { Self.size + 2 * Self.slack }

    var body: some View {
        Image(.padDpad)
            .resizable()
            .frame(width: Self.size, height: Self.size)
            .offset(tilt)
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { update(to: directions(at: $0.location)) }
                    .onEnded { _ in update(to: []) }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: pressed)
            .accessibilityElement()
            .accessibilityLabel("Directional pad")
    }

    /// Shift the pad slightly toward the pressed direction.
    private var tilt: CGSize {
        CGSize(
            width: (pressed.contains(.right) ? 2 : 0) - (pressed.contains(.left) ? 2 : 0),
            height: (pressed.contains(.down) ? 2 : 0) - (pressed.contains(.up) ? 2 : 0)
        )
    }

    /// Up to two directions (diagonals), split into 45° sectors around the center.
    private func directions(at location: CGPoint) -> Set<GamepadButton> {
        let dx = location.x - hitSize / 2
        let dy = location.y - hitSize / 2
        guard hypot(dx, dy) > deadZone else { return [] }
        let angle = atan2(-dy, dx) * 180 / .pi  // 0° = right, 90° = up
        var result: Set<GamepadButton> = []
        if abs(angle) < 67.5 { result.insert(.right) }
        if abs(angle) > 112.5 { result.insert(.left) }
        if angle > 22.5 && angle < 157.5 { result.insert(.up) }
        if angle < -22.5 && angle > -157.5 { result.insert(.down) }
        return result
    }

    private func update(to new: Set<GamepadButton>) {
        guard new != pressed else { return }
        for button in pressed.subtracting(new) { onChange(button, false) }
        for button in new.subtracting(pressed) { onChange(button, true) }
        pressed = new
    }
}

/// Press-and-hold behavior shared by the pad buttons (a SwiftUI `Button` only fires on release).
private struct HoldGesture: ViewModifier {
    let button: GamepadButton
    let onChange: (GamepadButton, Bool) -> Void
    @Binding var isPressed: Bool

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onChange(button, true)
                    }
                    .onEnded { _ in
                        isPressed = false
                        onChange(button, false)
                    }
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: isPressed) { _, new in new }
            .accessibilityAddTraits(.isButton)
    }
}

private struct RoundPadButton: View {
    let title: String
    let button: GamepadButton
    let onChange: (GamepadButton, Bool) -> Void

    @State private var isPressed = false
    static let size: CGFloat = 64

    var body: some View {
        Image(isPressed ? .padButtonPressed : .padButton)
            .resizable()
            .frame(width: Self.size, height: Self.size)
            .overlay {
                Text(title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.background)
                    .offset(y: isPressed ? 1 : -2)
            }
            .padding(8) // larger touch target than the drawn button
            .modifier(HoldGesture(button: button, onChange: onChange, isPressed: $isPressed))
            .accessibilityLabel(Text(title))
    }
}

private struct SmallPadButton: View {
    let title: LocalizedStringKey
    let button: GamepadButton
    let onChange: (GamepadButton, Bool) -> Void

    @State private var isPressed = false

    var body: some View {
        Text(title)
            .font(Theme.Fonts.pixelLabel)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: 66, height: 30)
            .background {
                Image(.padButtonSmall)
                    .resizable(capInsets: EdgeInsets(top: 19, leading: 20, bottom: 19, trailing: 20), resizingMode: .stretch)
            }
            .opacity(isPressed ? 0.7 : 1)
            .offset(y: isPressed ? 1 : 0)
            .padding(.vertical, 7) // 44 pt touch target
            .padding(.horizontal, 4)
            .modifier(HoldGesture(button: button, onChange: onChange, isPressed: $isPressed))
            .accessibilityLabel(Text(title))
    }
}

#Preview(traits: .landscapeLeft) {
    VirtualGamepadView { button, isPressed in
        print(button, isPressed)
    }
    .ignoresSafeArea(edges: .horizontal)
    .background { AppBackground(style: .pattern) }
}
