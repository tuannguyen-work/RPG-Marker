//
//  PlayerView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI
import WebKit

/// Full-screen, landscape game screen with the on-screen controller and a pause menu.
struct PlayerView: View {
    @State var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PreferenceKey.hasSeenControlsGuide) private var hasSeenControlsGuide = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let session = viewModel.session {
                WebGameView(webView: session.webView)
                    .ignoresSafeArea()
            } else if let message = viewModel.errorMessage {
                failure(message)
            } else {
                ProgressView()
                    .tint(Theme.Colors.gold)
                    .controlSize(.large)
            }

            if viewModel.session != nil && viewModel.showsControls {
                GeometryReader { geometry in
                    VirtualGamepadView(coversGame: coversGame(in: geometry.size)) { button, isPressed in
                        viewModel.handle(button, isPressed: isPressed)
                    }
                }
                .ignoresSafeArea(edges: .horizontal)
            }

            topBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if viewModel.session != nil && viewModel.showsControls && !hasSeenControlsGuide {
                ControlsGuideOverlay(turboTitle: "Turbo", turboMeaning: "Tap to play at 3× speed, tap again for normal.") {
                    hasSeenControlsGuide = true
                }
            }

            if viewModel.isPaused {
                PauseMenu(viewModel: viewModel) {
                    Task {
                        await viewModel.stop()
                        dismiss()
                    }
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { OrientationLock.set(.landscape) }
        .onDisappear { OrientationLock.set(.portrait) }
        .task { await viewModel.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.appDidBecomeActive()
            } else {
                viewModel.appWillResignActive()
            }
        }
    }

    /// Whether the side bars next to the letterboxed game are too narrow for the controls,
    /// as with widescreen games.
    private func coversGame(in screen: CGSize) -> Bool {
        guard let game = viewModel.gameSize, screen.height > 0 else { return false }
        let gameWidth = min(screen.width, screen.height * game.width / game.height)
        return (screen.width - gameWidth) / 2 < VirtualGamepadView.sideBarWidth
    }

    private var topBar: some View {
        HStack {
            Button {
                viewModel.isPaused = true
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
            Spacer()
            if viewModel.speed > 1 {
                Text("×\(viewModel.speed)")
                    .font(Theme.Fonts.pixelLabel)
                    .foregroundStyle(Theme.Colors.background)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.gold, in: Capsule())
                    .accessibilityLabel("Fast forward \(viewModel.speed) times")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .opacity(viewModel.isPaused ? 0 : 0.85)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Couldn't start this game")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(message)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Back to Library") { dismiss() }
                .buttonStyle(.pixel)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .pixelFrame(.window)
    }
}

private struct PauseMenu: View {
    @Bindable var viewModel: PlayerViewModel
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { viewModel.isPaused = false }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: Theme.Spacing.sm) {
                    PixelCursor()
                    Text("PAUSED")
                        .font(Theme.Fonts.pixelLabel)
                        .foregroundStyle(Theme.Colors.gold)
                }
                Text(viewModel.game.name)
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Button {
                    viewModel.isPaused = false
                } label: {
                    Text("Resume").frame(maxWidth: .infinity)
                }
                .buttonStyle(.pixel)

                HStack(spacing: 12) {
                    Button {
                        viewModel.toggleSpeed()
                    } label: {
                        Text(viewModel.speed == 1 ? "Speed ×1" : "Speed ×\(viewModel.speed)").frame(maxWidth: .infinity)
                    }
                    Button {
                        viewModel.showsControls.toggle()
                    } label: {
                        Text(viewModel.showsControls ? "Hide Controls" : "Show Controls").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.pixelSecondary)

                Button(action: onQuit) {
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

/// Hosts the session's web view. The view is owned by the session, so SwiftUI never recreates it.
private struct WebGameView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
