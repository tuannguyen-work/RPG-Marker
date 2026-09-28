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
    /// True when the game fills the screen behind the controls; they fade so the game stays readable.
    var coversGame = false
    /// The small button next to Menu: fast-forward for MV/MZ, dash for XP/VX/VX Ace.
    var turboTitle: LocalizedStringKey = "Turbo"
    var onChange: (GamepadButton, _ isPressed: Bool) -> Void

    /// Width each side needs for the controls not to overlap the game.
    static let sideBarWidth: CGFloat = 170

    /// From the screen edge: clears the Dynamic Island (either side) and keeps the buttons under
    /// the thumbs rather than at the very edge.
    private let edgeInset: CGFloat = 60
    /// Thumb resting height, as a fraction of the screen height.
    private let thumbLine: CGFloat = 0.6

    @AppStorage(PreferenceKey.controlsOpacity) private var opacity = 0.9
    @AppStorage(PreferenceKey.controlsSize) private var size = ControlsSize.medium

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let thumbY = geometry.size.height * thumbLine
            // Scaling keeps each group anchored on its thumb point; gestures scale with the drawing.
            let scale = size.scale

            // Left thumb: direction buttons on the resting point, the rarely used Turbo above them.
            // The direction cross is wide, so it sits a little closer to the edge than the A/B side.
            let dpadX = edgeInset - 10 + DirectionPad.size * scale / 2
            DirectionPad(onChange: onChange)
                .scaleEffect(scale)
                .position(x: dpadX, y: thumbY)
            SmallPadButton(title: turboTitle, button: .turbo, onChange: onChange)
                .scaleEffect(scale)
                .position(x: dpadX, y: thumbY - (DirectionPad.size / 2 + 30) * scale)

            // Right thumb: A (used most) on the resting point, B down and inward like a SNES pad,
            // Menu above within a short stretch.
            let aX = width - edgeInset - RoundPadButton.size * scale / 2
            RoundPadButton(title: "A", button: .confirm, onChange: onChange)
                .scaleEffect(scale)
                .position(x: aX, y: thumbY - 12 * scale)
            RoundPadButton(title: "B", button: .cancel, onChange: onChange)
                .scaleEffect(scale)
                .position(x: aX - 66 * scale, y: thumbY + 38 * scale)
            SmallPadButton(title: "Menu", button: .menu, onChange: onChange)
                .scaleEffect(scale)
                .position(x: aX - 40 * scale, y: thumbY - 78 * scale)
        }
        .opacity(coversGame ? opacity * 0.5 : opacity)
        .animation(.easeInOut, value: coversGame)
    }
}

/// Four separate direction buttons in a cross. One gesture covers the whole cross, so the thumb
/// can slide from one button to the next; the corners between two buttons press both (diagonal).
private struct DirectionPad: View {
    let onChange: (GamepadButton, Bool) -> Void

    @State private var pressed: Set<GamepadButton> = []
    @AppStorage(PreferenceKey.hapticsEnabled) private var hapticsEnabled = true

    private static let button: CGFloat = 56
    private static let gap: CGFloat = 4
    /// Cell size of the 3×3 grid the buttons sit in.
    private static let cell: CGFloat = button + gap
    static let size: CGFloat = 3 * cell
    /// Touches this far outside the cross still count, so a drifting thumb keeps control.
    private static let slack: CGFloat = 14

    var body: some View {
        ZStack {
            arrow(.up, rotation: 0).offset(y: -Self.cell)
            arrow(.right, rotation: 90).offset(x: Self.cell)
            arrow(.down, rotation: 180).offset(y: Self.cell)
            arrow(.left, rotation: 270).offset(x: -Self.cell)
        }
        .frame(width: Self.size + 2 * Self.slack, height: Self.size + 2 * Self.slack)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { update(to: directions(at: $0.location)) }
                .onEnded { _ in update(to: []) }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, _ in hapticsEnabled }
        .accessibilityElement()
        .accessibilityLabel("Directional pad")
    }

    private func arrow(_ direction: GamepadButton, rotation: Double) -> some View {
        let isPressed = pressed.contains(direction)
        return PixelArrow()
            .fill(isPressed ? Theme.Colors.ember : Theme.Colors.textPrimary)
            .frame(width: 20, height: 15)
            .rotationEffect(.degrees(rotation))
            .frame(width: Self.button, height: Self.button)
            .background {
                Image(.padButtonSmall)
                    .resizable(capInsets: EdgeInsets(top: 19, leading: 20, bottom: 19, trailing: 20), resizingMode: .stretch)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.Colors.ember.opacity(isPressed ? 0.3 : 0))
                            .padding(3)
                    }
            }
            .offset(y: isPressed ? 1 : 0)
    }

    /// The 3×3 cell under the finger: edges are single directions, corners diagonals, center none.
    private func directions(at location: CGPoint) -> Set<GamepadButton> {
        func index(_ value: CGFloat) -> Int {
            min(max(Int((value - Self.slack) / Self.cell), 0), 2)
        }
        let column = index(location.x)
        let row = index(location.y)
        var result: Set<GamepadButton> = []
        if row == 0 { result.insert(.up) }
        if row == 2 { result.insert(.down) }
        if column == 0 { result.insert(.left) }
        if column == 2 { result.insert(.right) }
        return result
    }

    private func update(to new: Set<GamepadButton>) {
        guard new != pressed else { return }
        for button in pressed.subtracting(new) { onChange(button, false) }
        for button in new.subtracting(pressed) { onChange(button, true) }
        pressed = new
    }
}

/// Upward pointing triangle drawn in pixel steps, matching the pixel-art buttons.
private struct PixelArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let rows = 4
        let step = rect.height / CGFloat(rows)
        for row in 0..<rows {
            // Each row is wider than the one above, centered: a stepped triangle.
            let width = rect.width * CGFloat(row + 1) / CGFloat(rows)
            path.addRect(CGRect(x: rect.midX - width / 2, y: rect.minY + CGFloat(row) * step, width: width, height: step))
        }
        return path
    }
}

/// Press-and-hold behavior shared by the pad buttons (a SwiftUI `Button` only fires on release).
private struct HoldGesture: ViewModifier {
    let button: GamepadButton
    let onChange: (GamepadButton, Bool) -> Void
    @Binding var isPressed: Bool
    @AppStorage(PreferenceKey.hapticsEnabled) private var hapticsEnabled = true

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
            .sensoryFeedback(.impact(weight: .medium), trigger: isPressed) { _, new in new && hapticsEnabled }
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
