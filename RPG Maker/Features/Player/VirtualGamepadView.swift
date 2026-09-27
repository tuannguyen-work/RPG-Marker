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
struct VirtualGamepadView: View {
    var onChange: (GamepadButton, _ isPressed: Bool) -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            DPadView(onChange: onChange)
            Spacer()
            VStack(alignment: .trailing, spacing: 20) {
                HStack(spacing: 12) {
                    SmallPadButton(title: "Menu", button: .menu, onChange: onChange)
                    SmallPadButton(title: "Turbo", button: .turbo, onChange: onChange)
                }
                HStack(alignment: .top, spacing: 18) {
                    RoundPadButton(title: "B", button: .cancel, onChange: onChange)
                        .offset(y: 28)
                    RoundPadButton(title: "A", button: .confirm, onChange: onChange)
                }
                .padding(.bottom, 28)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }
}

private struct DPadView: View {
    let onChange: (GamepadButton, Bool) -> Void

    @State private var pressed: Set<GamepadButton> = []
    private let size: CGFloat = 132
    private let deadZone: CGFloat = 14

    var body: some View {
        Image(.padDpad)
            .resizable()
            .frame(width: size, height: size)
            .offset(tilt)
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
        let dx = location.x - size / 2
        let dy = location.y - size / 2
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

    var body: some View {
        Image(isPressed ? .padButtonPressed : .padButton)
            .resizable()
            .frame(width: 72, height: 72)
            .overlay {
                Text(title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.background)
                    .offset(y: isPressed ? 1 : -2)
            }
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
            .frame(width: 76, height: 32)
            .background {
                Image(.padButtonSmall)
                    .resizable(capInsets: EdgeInsets(top: 19, leading: 20, bottom: 19, trailing: 20), resizingMode: .stretch)
            }
            .opacity(isPressed ? 0.7 : 1)
            .offset(y: isPressed ? 1 : 0)
            .modifier(HoldGesture(button: button, onChange: onChange, isPressed: $isPressed))
            .accessibilityLabel(Text(title))
    }
}

#Preview(traits: .landscapeLeft) {
    VirtualGamepadView { button, isPressed in
        print(button, isPressed)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background { AppBackground(style: .pattern) }
}
