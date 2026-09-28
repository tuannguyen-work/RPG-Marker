//
//  Feedback.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Cards and tiles shrink slightly under the finger and spring back.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// A short message that slides in from the top and hides itself.
struct Toast: Equatable, Identifiable {
    enum Kind { case success, info, error }

    let id = UUID()
    let kind: Kind
    let message: String

    static func success(_ message: String) -> Toast { Toast(kind: .success, message: message) }
    static func info(_ message: String) -> Toast { Toast(kind: .info, message: message) }
    static func error(_ message: String) -> Toast { Toast(kind: .error, message: message) }
}

struct ToastView: View {
    let toast: Toast

    private var icon: String {
        switch toast.kind {
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch toast.kind {
        case .success: Theme.Colors.gold
        case .info: Theme.Colors.textPrimary
        case .error: Theme.Colors.ember
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: toast.id)
            Text(toast.message)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .pixelFrame(.window)
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Shows `toast` at the top of the view for a few seconds, then clears the binding.
    func toast(_ toast: Binding<Toast?>) -> some View {
        overlay(alignment: .top) {
            if let current = toast.wrappedValue {
                ToastView(toast: current)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: current.id) {
                        try? await Task.sleep(for: .seconds(2.6))
                        if toast.wrappedValue?.id == current.id {
                            toast.wrappedValue = nil
                        }
                    }
                    .onTapGesture { toast.wrappedValue = nil }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast.wrappedValue)
    }
}

/// Small pill shown while saves are fetched from iCloud before a game starts.
struct SyncingBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(Theme.Colors.gold)
            Text("Syncing iCloud saves…")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.Colors.surfaceRaised, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.Colors.gold.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }
}
