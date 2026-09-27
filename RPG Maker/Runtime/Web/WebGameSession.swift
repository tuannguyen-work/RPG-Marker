//
//  WebGameSession.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation
import WebKit
import os

/// Runs an RPG Maker MV/MZ game in a WKWebView.
///
/// The game's own JavaScript engine does the work; this class serves its files, persists its saves
/// through `GameSaveStore`, and forwards controller input as keyboard events.
final class WebGameSession: NSObject {
    let webView: WKWebView
    private let saveStore: GameSaveStore
    private var saveWrites: Task<Void, Never>?

    /// Loads the saves first: they are handed to the page before any game script runs.
    static func make(contentRoot: URL, saveStore: GameSaveStore) async throws -> WebGameSession {
        let saves = try await saveStore.loadAll()
        return try WebGameSession(contentRoot: contentRoot, saveStore: saveStore, saves: saves)
    }

    private init(contentRoot: URL, saveStore: GameSaveStore, saves: [String: String]) throws {
        self.saveStore = saveStore

        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(GameFileSchemeHandler(root: contentRoot), forURLScheme: GameFileSchemeHandler.scheme)
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsInlineMediaPlayback = true
        // Saves go through the bridge; nothing needs to persist in WebKit's own storage.
        configuration.websiteDataStore = .nonPersistent()

        let bridgeURL = Bundle.main.url(forResource: "qp-bridge", withExtension: "js")!
        let bridge = try String(contentsOf: bridgeURL, encoding: .utf8)
        let savesJSON = String(decoding: try JSONEncoder().encode(saves), as: UTF8.self)
        configuration.userContentController.addUserScript(WKUserScript(
            source: "window.__QP_STORE__ = \(savesJSON);\n\(bridge)",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        #if DEBUG
        webView.isInspectable = true
        #endif

        super.init()
        // The content controller retains its handlers; a weak proxy avoids a retain cycle.
        configuration.userContentController.add(WeakMessageHandler(self), name: "qpStorage")
        webView.load(URLRequest(url: GameFileSchemeHandler.entryURL))
    }

    func tearDown() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "qpStorage")
        webView.stopLoading()
    }

    // MARK: - Input

    /// Keyboard codes understood by both MV and MZ (`Input.keyMapper`).
    private static func keyCode(for button: GamepadButton) -> Int? {
        switch button {
        case .up: 38
        case .down: 40
        case .left: 37
        case .right: 39
        case .confirm: 13  // Enter → "ok"
        case .cancel: 88   // X → "escape" (cancel)
        case .menu: 27     // Escape → "escape" (menu)
        case .turbo: nil   // handled by the app
        }
    }

    func send(_ button: GamepadButton, isPressed: Bool) {
        guard let code = Self.keyCode(for: button) else { return }
        webView.evaluateJavaScript("window.__qp && window.__qp.key(\(code), \(isPressed))")
    }

    func setSpeed(_ speed: Int) {
        webView.evaluateJavaScript("window.__qp && window.__qp.setSpeed(\(speed))")
    }

    func setPaused(_ isPaused: Bool) {
        webView.evaluateJavaScript("window.__qp && window.__qp.setPaused(\(isPaused))")
    }

    // MARK: - Saves

    fileprivate func handle(_ body: Any) {
        guard let message = body as? [String: Any], let op = message["op"] as? String else { return }
        let key = message["key"] as? String
        switch op {
        case "set":
            guard let key, let value = message["value"] as? String else { return }
            enqueue { try await $0.set(value, for: key) }
        case "remove":
            guard let key else { return }
            enqueue { await $0.remove(key) }
        case "log":
            let text = message["message"] as? String ?? ""
            Logger.runtime.error("Game \(message["level"] as? String ?? "", privacy: .public): \(text, privacy: .public)")
            DebugLog.write("[game \(message["level"] as? String ?? "")] \(text)")
        default:
            break
        }
    }

    /// Chains writes so they reach the disk in the order the game made them.
    private func enqueue(_ write: @escaping @Sendable (GameSaveStore) async throws -> Void) {
        let previous = saveWrites
        let store = saveStore
        saveWrites = Task {
            await previous?.value
            do {
                try await write(store)
            } catch {
                Logger.runtime.error("Save write failed: \(error.localizedDescription)")
            }
        }
    }

    /// Waits until every save the game made has been written.
    func flushSaves() async {
        await saveWrites?.value
    }
}

private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var session: WebGameSession?

    init(_ session: WebGameSession) {
        self.session = session
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        session?.handle(message.body)
    }
}
