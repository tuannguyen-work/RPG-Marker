//
//  OnboardingView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [Page] = [
        Page(
            image: .onboardingImport,
            title: "Bring your own games",
            message: "Import games you own straight from the Files app. Nothing is downloaded or included."
        ),
        Page(
            image: .onboardingLibrary,
            title: "Your personal library",
            message: "Each game is detected automatically and keeps its own saves, play time and settings."
        ),
        Page(
            image: .onboardingPlay,
            title: "Pick up where you left off",
            message: "Play full screen in landscape with touch controls or a game controller."
        ),
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    if isLastPage {
                        onFinish()
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(isLastPage ? "Get Started" : "Next").frame(maxWidth: .infinity)
                }
                .buttonStyle(.pixel)

                Button("Skip", action: onFinish)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(minHeight: 44)
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, Theme.Spacing.lg)
        .background { AppBackground(style: .pattern) }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: 0)
            Image(page.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 320)
                .accessibilityHidden(true)
            OrnamentDivider()
            VStack(spacing: Theme.Spacing.sm) {
                Text(page.title)
                    .font(Theme.Fonts.largeTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(page.message)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            Spacer(minLength: 48)
        }
    }

    private struct Page {
        let image: ImageResource
        let title: LocalizedStringKey
        let message: LocalizedStringKey
    }
}

#Preview {
    OnboardingView {}
        .preferredColorScheme(.dark)
}
