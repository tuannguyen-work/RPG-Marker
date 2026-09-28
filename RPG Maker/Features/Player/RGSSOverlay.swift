//
//  RGSSOverlay.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// State of a running mkxp-z game, shared by its overlay and RGSSPlayerView.
@Observable
final class RGSSSession {
    let title: String
    private(set) var isPaused = false
    var showsControls = true
    /// Paused because the app left the foreground, not by the player.
    private var pausedForBackground = false

    init(title: String) {
        self.title = title
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        MKXPSetPaused(paused)
    }

    func appDidBecomeActive() {
        if pausedForBackground {
            pausedForBackground = false
            setPaused(false)
        }
    }

    /// The game must not render while the app is in the background (iOS terminates GL apps that do).
    func appWillResignActive() {
        if !isPaused {
            pausedForBackground = true
            setPaused(true)
        }
    }

    func quit() {
        // A halted game can't process the quit request.
        setPaused(false)
        MKXPRequestQuit()
    }

    /// SDL scancodes for mkxp-z's default bindings (src/input/keybindings.cpp).
    func handle(_ button: GamepadButton, isPressed: Bool) {
        let scancode: Int32 = switch button {
        case .up: 82
        case .down: 81
        case .left: 80
        case .right: 79
        case .confirm: 40  // Return → Input::C
        case .cancel: 27   // X → Input::B
        case .menu: 41     // Escape → Input::B (opens the menu)
        case .turbo: 225   // Left Shift → Input::A (dash)
        }
        MKXPSetKey(scancode, isPressed)
    }
}

/// On-screen controls and pause menu laid over mkxp-z's window.
struct RGSSOverlayView: View {
    @Bindable var session: RGSSSession
    @AppStorage(PreferenceKey.hasSeenControlsGuide) private var hasSeenControlsGuide = false

    var body: some View {
        ZStack {
            if session.showsControls && !session.isPaused {
                VirtualGamepadView(turboTitle: "Dash") { button, isPressed in
                    session.handle(button, isPressed: isPressed)
                }
                .ignoresSafeArea(edges: .horizontal)
            }

            if !session.isPaused {
                Button {
                    session.setPaused(true)
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 40, height: 32)
                        .background {
                            Image(.padButtonSmall)
                                .resizable(capInsets: EdgeInsets(top: 19, leading: 20, bottom: 19, trailing: 20), resizingMode: .stretch)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Pause")
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(0.85)
            } else {
                pauseMenu
            }

            if session.showsControls && !session.isPaused && !hasSeenControlsGuide {
                ControlsGuideOverlay(turboTitle: "Dash", turboMeaning: "Hold while moving to run.") {
                    hasSeenControlsGuide = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { session.setPaused(false) }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: Theme.Spacing.sm) {
                    PixelCursor()
                    Text("PAUSED")
                        .font(Theme.Fonts.pixelLabel)
                        .foregroundStyle(Theme.Colors.gold)
                }
                Text(session.title)
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Button {
                    session.setPaused(false)
                } label: {
                    Text("Resume").frame(maxWidth: .infinity)
                }
                .buttonStyle(.pixel)

                Button {
                    session.showsControls.toggle()
                } label: {
                    Text(session.showsControls ? "Hide Controls" : "Show Controls").frame(maxWidth: .infinity)
                }
                .buttonStyle(.pixelSecondary)

                Button {
                    session.quit()
                } label: {
                    Text("Quit Game").frame(maxWidth: .infinity)
                }
                .buttonStyle(.pixelSecondary)

                Text("Save in the game's menu before quitting.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(22)
            .frame(width: 380)
            .pixelFrame(.window)
        }
    }
}
