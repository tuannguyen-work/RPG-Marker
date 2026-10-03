//
//  HelpCenterView.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import SwiftUI

enum GuideTopic: String, CaseIterable, Identifiable, Hashable {
    case importing, engines, controls, saves, troubleshooting

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .importing: "Add Your First Game"
        case .engines: "Which Games Work"
        case .controls: "Controls"
        case .saves: "Saves & iCloud"
        case .troubleshooting: "Troubleshooting"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .importing: "From a download to playing, in four steps."
        case .engines: "Supported engines and how to tell which one a game uses."
        case .controls: "The on-screen buttons, touch and the pause menu."
        case .saves: "Where your progress lives and how to move it between devices."
        case .troubleshooting: "Fixes for the most common problems."
        }
    }

    var systemImage: String {
        switch self {
        case .importing: "square.and.arrow.down.fill"
        case .engines: "checkmark.seal.fill"
        case .controls: "gamecontroller.fill"
        case .saves: "icloud.fill"
        case .troubleshooting: "wrench.and.screwdriver.fill"
        }
    }

    var illustration: ImageResource {
        switch self {
        case .importing: .guideImport
        case .engines: .guideEngines
        case .controls: .guideControls
        case .saves: .guideSaves
        case .troubleshooting: .guideHelp
        }
    }
}

/// Index of the guide. Pushed from Settings, or shown in a sheet with `HelpSheet`.
struct HelpCenterView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavigationLink(value: GuideTopic.importing) {
                    FeaturedTopicCard(topic: .importing)
                }
                .buttonStyle(.pressable)

                ForEach(GuideTopic.allCases.dropFirst()) { topic in
                    NavigationLink(value: topic) {
                        TopicRow(topic: topic)
                    }
                    .buttonStyle(.pressable)
                }

                GuideTip(
                    text: "This app doesn't include or sell games. Play games you've bought or downloaded from their creators.",
                    systemImage: "info.circle.fill"
                )
                .padding(.top, 6)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background { AppBackground(style: .pattern) }
        .navigationTitle("Guide")
        .navigationDestination(for: GuideTopic.self) { topic in
            GuideArticleView(topic: topic)
        }
    }
}

/// The guide in its own navigation stack, optionally opened on a topic.
struct HelpSheet: View {
    var initialTopic: GuideTopic?
    @Environment(\.dismiss) private var dismiss
    @State private var path: [GuideTopic] = []

    var body: some View {
        NavigationStack(path: $path) {
            HelpCenterView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .tint(Theme.Colors.ember)
        .preferredColorScheme(.dark)
        .onAppear {
            if let initialTopic, path.isEmpty { path = [initialTopic] }
        }
    }
}

private struct FeaturedTopicCard: View {
    let topic: GuideTopic

    var body: some View {
        HStack(spacing: 14) {
            Image(topic.illustration)
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("START HERE")
                    .font(Theme.Fonts.pixelLabel)
                    .foregroundStyle(Theme.Colors.gold)
                Text(topic.title)
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(topic.summary)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .pixelFrame(.window)
        .accessibilityElement(children: .combine)
    }
}

private struct TopicRow: View {
    let topic: GuideTopic

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: topic.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Colors.gold)
                .frame(width: 42, height: 42)
                .background(Theme.Colors.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(topic.title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(topic.summary)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(14)
        .pixelFrame(.card)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Articles

struct GuideArticleView: View {
    let topic: GuideTopic

    var body: some View {
        GuidePage(topic: topic) {
            switch topic {
            case .importing: ImportArticle()
            case .engines: EnginesArticle()
            case .controls: ControlsArticle()
            case .saves: SavesArticle()
            case .troubleshooting: TroubleshootingArticle()
            }
        }
    }
}

private struct ImportArticle: View {
    var body: some View {
        GuideStep(number: 1, title: "Get the PC version", text: "Download the **Windows** version of an RPG Maker game you own, from the creator's page or a store like itch.io. It usually comes as a ZIP file.") {
            ZipContentsDiagram()
        }
        GuideStep(number: 2, title: "Save it to Files", text: "Keep the ZIP in the Files app, in **On My iPhone** or **iCloud Drive**. Safari saves downloads to the **Downloads** folder.") {
            FilesDiagram()
        }
        GuideStep(number: 3, title: "Import it", text: "In the Library, tap **+** and choose the ZIP, or the game's folder if it's already extracted. The engine is detected for you.") {
            ImportFlowDiagram()
        }
        GuideStep(number: 4, title: "Play", text: "Tap the game's card. It opens full screen in landscape, with on-screen buttons.") {
            PlayDiagram()
        }
        GuideTip(text: "You can also open a ZIP from Files or Safari: tap **Share**, then choose this app.", systemImage: "square.and.arrow.up")
        GuideTip(text: "7z and RAR files can't be imported yet. Extract them with another app first, then import the folder.")
    }
}

private struct EnginesArticle: View {
    var body: some View {
        GuideSection(title: "Supported") {
            Text("RPG Maker **XP**, **VX**, **VX Ace**, **MV** and **MZ** games made for Windows. Look inside the game's folder for these files:")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            EngineFilesDiagram()
        }
        GuideSection(title: "Good to know") {
            GuideRow(systemImage: "puzzlepiece.extension.fill", title: "Windows-only add-ons", text: "Some games rely on extra Windows programs or plugins. They may start but miss features, or not run at all.")
            GuideRow(systemImage: "doc.questionmark.fill", title: "Project files aren't games", text: "A game's editor project without its images is source code. Download the playable release instead.")
            GuideRow(systemImage: "lock.fill", title: "Encrypted games are fine", text: "Games packed or encrypted by RPG Maker's own deployment play normally.")
        }
    }
}

private struct ControlsArticle: View {
    var body: some View {
        GuideSection(title: "On-screen buttons") {
            ControlsDiagram()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            GuideRow(systemImage: "1.circle.fill", title: "Direction pad", text: "Move and pick menu items. Slide your thumb between arrows; corners move diagonally.")
            GuideRow(systemImage: "2.circle.fill", title: "Turbo / Dash", text: "MV and MZ: tap to play at 3× speed. XP, VX and VX Ace: hold while moving to run.")
            GuideRow(systemImage: "3.circle.fill", title: "A · Confirm", text: "Talk, open chests, select.")
            GuideRow(systemImage: "4.circle.fill", title: "B · Cancel", text: "Go back. In many games it also opens the menu.")
            GuideRow(systemImage: "5.circle.fill", title: "Menu", text: "Opens the game's main menu.")
            GuideRow(systemImage: "6.circle.fill", title: "Pause", text: "Change speed, hide the buttons or quit the game.")
        }
        GuideSection(title: "Touch") {
            GuideRow(systemImage: "hand.tap.fill", title: "Tap to move", text: "In MV and MZ games, tap the map to walk there and tap menu items to choose them.")
            GuideRow(systemImage: "hand.point.up.left.and.text.fill", title: "Two-finger tap", text: "Goes back or opens the menu in MV and MZ games.")
        }
        GuideTip(text: "Make the buttons bigger, smaller or more see-through in **Settings → On-Screen Controls**.", systemImage: "slider.horizontal.3")
    }
}

private struct SavesArticle: View {
    var body: some View {
        GuideSection(title: "Saving") {
            GuideRow(systemImage: "square.and.arrow.down.fill", title: "Save in the game", text: "Use the game's own Save menu, as on a computer. Quitting doesn't save for you.")
            GuideRow(systemImage: "externaldrive.fill", title: "Kept apart from the game", text: "Saves are stored separately, so updating or re-importing a game keeps your progress.")
        }
        GuideSection(title: "iCloud") {
            SaveSyncDiagram()
                .frame(maxWidth: .infinity)
            Text("With **iCloud Saves** on, your saves sync to your other iPhones and iPads signed in to the same Apple Account. Import the same game there and your progress is waiting.")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("Deleting a game keeps its saves in iCloud; import it again to get them back.")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        GuideSection(title: "Export & Import") {
            GuideRow(systemImage: "square.and.arrow.up", title: "Export", text: "Open a game's details (•••) and tap **Export** to share its saves as a ZIP.")
            GuideRow(systemImage: "square.and.arrow.down", title: "Import", text: "Tap **Import** in the same place to bring saves back from a ZIP or from save files.")
        }
    }
}

private struct TroubleshootingArticle: View {
    var body: some View {
        GuideSection(title: "Importing") {
            FAQItem(question: "“This game is missing its image files”", answer: "You picked the game's editor project, not the finished game. Download the playable release from the creator.")
            FAQItem(question: "“No RPG Maker game was found”", answer: "Check the engine list in Which Games Work. RPG Maker 2000 and 2003 games aren't supported yet. Some downloads contain an installer (.exe) rather than the game; those can't be opened on iPhone.")
            FAQItem(question: "7z or RAR file won't import", answer: "Only ZIP files and folders can be imported for now. Extract the archive with another app, then import the folder.")
            FAQItem(question: "Import is slow", answer: "Big games can be several gigabytes. Keep the app open until the import finishes.")
        }
        GuideSection(title: "Playing") {
            FAQItem(question: "Black screen or an error when starting", answer: "The game may need a Windows-only plugin or program. Missing plugins are skipped automatically, but some games can't run without them. Try the latest version of the game.")
            FAQItem(question: "No sound", answer: "Check the volume and that the ringer switch isn't muting your iPhone. Some games start music only after the first tap.")
            FAQItem(question: "The game runs slowly", answer: "Large games can be demanding on older devices. Close other apps, and use Turbo to speed up slow scenes.")
            FAQItem(question: "Buttons cover the game", answer: "In widescreen games the buttons fade automatically. You can hide them from the pause menu, or make them smaller in Settings.")
        }
        GuideSection(title: "Saves") {
            FAQItem(question: "Where are my saves?", answer: "Open the game's details (•••) to see its save files. With iCloud Saves on, they're also in your iCloud.")
            FAQItem(question: "My progress didn't appear on another device", answer: "Make sure both devices use the same Apple Account with iCloud Drive on, and that iCloud Saves is on in Settings. Syncing happens when a game starts and ends.")
        }
    }
}

#Preview {
    HelpSheet()
}

#Preview("Import") {
    NavigationStack { GuideArticleView(topic: .importing) }
        .preferredColorScheme(.dark)
}
