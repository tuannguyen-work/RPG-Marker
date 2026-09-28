//
//  GuideComponents.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

/// Scrolling page shared by the guide articles: illustrated header, then sections.
struct GuidePage<Content: View>: View {
    let topic: GuideTopic
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(spacing: Theme.Spacing.md) {
                    Image(topic.illustration)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 190)
                        .accessibilityHidden(true)
                    Text(topic.title)
                        .font(Theme.Fonts.largeTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(topic.summary)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    OrnamentDivider()
                }
                .frame(maxWidth: .infinity)

                content
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background { AppBackground(style: .pattern) }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A numbered step with an optional diagram.
struct GuideStep<Diagram: View>: View {
    let number: Int
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    @ViewBuilder var diagram: Diagram

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(number)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.background)
                    .frame(width: 28, height: 28)
                    .background(Theme.Colors.gold, in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Step \(number)")
                Text(title)
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Text(text)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            diagram
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelFrame(.window)
    }
}

extension GuideStep where Diagram == EmptyView {
    init(number: Int, title: LocalizedStringKey, text: LocalizedStringKey) {
        self.init(number: number, title: title, text: text) { EmptyView() }
    }
}

/// Titled panel for non-step content.
struct GuideSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: Theme.Spacing.sm) {
                PixelCursor()
                Text(title)
                    .font(Theme.Fonts.pixelLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.gold)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelFrame(.window)
    }
}

/// Icon + text row for lists inside sections.
struct GuideRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(text)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Highlighted hint.
struct GuideTip: View {
    let text: LocalizedStringKey
    var systemImage = "lightbulb.fill"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.Colors.gold)
            Text(text)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.Colors.gold.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Question that expands to its answer.
struct FAQItem: View {
    let question: LocalizedStringKey
    let answer: LocalizedStringKey
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(question)
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.Colors.gold)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapses the answer" : "Shows the answer")

            if isExpanded {
                Text(answer)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .clipped()
    }
}
