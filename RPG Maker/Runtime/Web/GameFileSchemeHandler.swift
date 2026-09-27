//
//  GameFileSchemeHandler.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation
import UniformTypeIdentifiers
import WebKit
import os

/// Serves a game's folder to the web view as `qpgame://game/<path>`.
///
/// A custom scheme (instead of `file://`) lets the engine load data with XMLHttpRequest, and lets us:
/// - match file names case-insensitively (games made on Windows often reference "Title.png" for "title.png"),
/// - answer byte-range requests for audio and video,
/// - append the engine patch to the managers script.
final class GameFileSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "qpgame"
    static let entryURL = URL(string: "\(scheme)://game/index.html")!

    /// Evaluated right after the engine's managers script, so StorageManager/SceneManager can be patched.
    private nonisolated static let managersScripts: Set<String> = ["rpg_managers.js", "rmmz_managers.js"]
    private nonisolated static let managersPatch = Data("\n;window.__qp && window.__qp.patchEngine();\n".utf8)

    private let root: URL
    private let resolver: CaseInsensitiveResolver
    private let cipher: RPGMakerCipher?
    private let mvAudio: MVAudio?
    private var activeTasks = Set<ObjectIdentifier>()

    init(root: URL, engine: GameEngine) {
        self.root = root.standardizedFileURL
        self.resolver = CaseInsensitiveResolver(root: self.root)
        self.cipher = RPGMakerCipher(contentRoot: self.root)
        self.mvAudio = engine == .mv ? MVAudio(cipher: cipher) : nil
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        let id = ObjectIdentifier(task)
        activeTasks.insert(id)
        let request = task.request
        let resolver = resolver
        let mvAudio = mvAudio
        let cipher = cipher

        Task.detached(priority: .userInitiated) {
            let result = Self.response(for: request, resolver: resolver, mvAudio: mvAudio, cipher: cipher)
            await MainActor.run {
                // WebKit raises if a stopped task is answered.
                guard self.activeTasks.remove(id) != nil else { return }
                switch result {
                case .success(let (response, data)):
                    task.didReceive(response)
                    task.didReceive(data)
                    task.didFinish()
                case .failure(let error):
                    task.didFailWithError(error)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {
        activeTasks.remove(ObjectIdentifier(task))
    }

    // MARK: - Response

    private nonisolated static func response(for request: URLRequest, resolver: CaseInsensitiveResolver, mvAudio: MVAudio?, cipher: RPGMakerCipher?) -> Result<(URLResponse, Data), Error> {
        guard let url = request.url else { return .failure(URLError(.badURL)) }
        let path = url.path(percentEncoded: false)

        if let mvAudio, let source = mvAudio.oggSource(for: path, resolver: resolver) {
            return transcodedResponse(url: url, ogg: source.file, cipher: source.isEncrypted ? mvAudio.cipher : nil)
        }

        guard var file = resolver.resolve(path) else {
            // MV shows img/system/Loading.png with a plain <img>, bypassing its own decrypter.
            if let cipher, path.lowercased().hasSuffix(".png"),
               let png = decryptedSibling(of: path, extensions: ["rpgmvp", "png_"], resolver: resolver, cipher: cipher) {
                let headers = ["Content-Type": "image/png", "Content-Length": String(png.count), "Access-Control-Allow-Origin": "*"]
                return .success((HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!, png))
            }
            Logger.runtime.debug("404 \(path, privacy: .public)")
            DebugLog.write("[404] \(path)")
            return .success((HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!, Data()))
        }
        file = file.standardizedFileURL
        return response(for: request, url: url, file: file)
    }

    private nonisolated static func decryptedSibling(of path: String, extensions: [String], resolver: CaseInsensitiveResolver, cipher: RPGMakerCipher) -> Data? {
        let stem = String(path[..<(path.lastIndex(of: ".") ?? path.endIndex)])
        for encryptedExtension in extensions {
            if let file = resolver.resolve("\(stem).\(encryptedExtension)"),
               let data = try? Data(contentsOf: file),
               let decrypted = cipher.decrypt(data) {
                return decrypted
            }
        }
        return nil
    }

    /// RPG Maker MV can't decode Vorbis on iOS: its Ogg audio (plain or encrypted) is served as WAV.
    /// MZ ships its own Vorbis decoder and is left alone.
    nonisolated struct MVAudio: Sendable {
        let cipher: RPGMakerCipher?

        /// The Ogg file to convert for a requested audio path, if any.
        func oggSource(for path: String, resolver: CaseInsensitiveResolver) -> (file: URL, isEncrypted: Bool)? {
            let lowercased = path.lowercased()
            let stem = String(path[..<(path.lastIndex(of: ".") ?? path.endIndex)])
            switch (lowercased as NSString).pathExtension {
            // Requested directly, e.g. by plugins that bypass the mobile default of .m4a.
            case "ogg": return resolver.resolve(path).map { ($0, false) }
            case "rpgmvo": return resolver.resolve(path).map { ($0, true) }
            // MV asks for .m4a on mobile devices; many PC releases only ship .ogg.
            case "m4a": return resolver.resolve(path) == nil ? resolver.resolve(stem + ".ogg").map { ($0, false) } : nil
            case "rpgmvm": return resolver.resolve(path) == nil ? resolver.resolve(stem + ".rpgmvo").map { ($0, true) } : nil
            default: return nil
            }
        }
    }

    /// Serves an Ogg file as WAV, re-encrypted when the game expects encrypted audio. Loop points travel
    /// in headers, read by the MV patch in qp-bridge.js. Files that aren't Ogg Vorbis (renamed .m4a,
    /// Opus) are passed through unchanged for the engine and WebKit to handle.
    private nonisolated static func transcodedResponse(url: URL, ogg: URL, cipher: RPGMakerCipher?) -> Result<(URLResponse, Data), Error> {
        guard let raw = try? Data(contentsOf: ogg, options: .mappedIfSafe) else { return .failure(URLError(.fileDoesNotExist)) }
        let data = cipher.flatMap { $0.decrypt(raw) } ?? raw
        if data.count >= 8, data[data.startIndex + 4 ..< data.startIndex + 8] == Data("ftyp".utf8) {
            return passthrough(url: url, file: ogg, contentType: "audio/mp4")
        }
        do {
            let output = try OggTranscoder.wav(fromOgg: data, identity: ogg)
            let body = cipher.map { $0.encrypt(output.wav) } ?? output.wav
            var headers = [
                "Content-Type": "audio/wav",
                "Content-Length": String(body.count),
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Expose-Headers": "X-QP-Sample-Rate, X-QP-Loop-Start, X-QP-Loop-Length",
                "X-QP-Sample-Rate": String(output.sampleRate),
            ]
            headers["X-QP-Loop-Start"] = output.loopStart.map(String.init)
            headers["X-QP-Loop-Length"] = output.loopLength.map(String.init)
            return .success((HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!, body))
        } catch {
            DebugLog.write("[transcode failed] \(ogg.lastPathComponent): \(error)")
            return passthrough(url: url, file: ogg, contentType: "audio/ogg")
        }
    }

    private nonisolated static func passthrough(url: URL, file: URL, contentType: String) -> Result<(URLResponse, Data), Error> {
        do {
            let data = try Data(contentsOf: file, options: .mappedIfSafe)
            let headers = ["Content-Type": contentType, "Content-Length": String(data.count), "Access-Control-Allow-Origin": "*"]
            return .success((HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!, data))
        } catch {
            return .failure(error)
        }
    }

    private nonisolated static func response(for request: URLRequest, url: URL, file: URL) -> Result<(URLResponse, Data), Error> {
        do {
            let size = (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            var headers = [
                "Content-Type": mimeType(for: file),
                "Accept-Ranges": "bytes",
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "no-cache",
            ]

            if let range = byteRange(request.value(forHTTPHeaderField: "Range"), size: size) {
                let handle = try FileHandle(forReadingFrom: file)
                defer { try? handle.close() }
                try handle.seek(toOffset: UInt64(range.lowerBound))
                let data = try handle.read(upToCount: range.count) ?? Data()
                headers["Content-Range"] = "bytes \(range.lowerBound)-\(range.upperBound - 1)/\(size)"
                headers["Content-Length"] = String(data.count)
                return .success((HTTPURLResponse(url: url, statusCode: 206, httpVersion: "HTTP/1.1", headerFields: headers)!, data))
            }

            var data = try Data(contentsOf: file, options: .mappedIfSafe)
            if managersScripts.contains(file.lastPathComponent.lowercased()) {
                data.append(managersPatch)
            }
            headers["Content-Length"] = String(data.count)
            return .success((HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!, data))
        } catch {
            return .failure(error)
        }
    }

    /// Parses "bytes=start-end" / "bytes=start-" / "bytes=-suffix".
    private nonisolated static func byteRange(_ header: String?, size: Int) -> Range<Int>? {
        guard let header, header.hasPrefix("bytes="), size > 0 else { return nil }
        let parts = header.dropFirst(6).split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let start: Int
        let end: Int
        if parts[0].isEmpty, let suffix = Int(parts[1]) {
            start = max(size - suffix, 0)
            end = size - 1
        } else if let first = Int(parts[0]) {
            start = first
            end = Int(parts[1]).map { min($0, size - 1) } ?? size - 1
        } else {
            return nil
        }
        guard start <= end, start < size else { return nil }
        return start..<(end + 1)
    }

    private nonisolated static func mimeType(for file: URL) -> String {
        switch file.pathExtension.lowercased() {
        case "js": "text/javascript"
        case "json": "application/json"
        case "ogg": "audio/ogg"
        case "m4a": "audio/mp4"
        case "wasm": "application/wasm"
        default: UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
    }
}

/// Maps a URL path to a file under `root`, ignoring case when the exact name doesn't exist.
/// Never returns a file outside `root`.
nonisolated final class CaseInsensitiveResolver: @unchecked Sendable {
    private let root: URL
    private let lock = NSLock()
    private var listings: [String: [String: String]] = [:]

    init(root: URL) {
        self.root = root
    }

    func resolve(_ path: String) -> URL? {
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty, !components.contains(".."), !components.contains(".") else { return nil }

        let exact = root.appending(path: components.joined(separator: "/"))
        if FileManager.default.fileExists(atPath: exact.path) { return exact }

        var current = root
        for component in components {
            guard let name = listing(of: current)[component.lowercased()] else { return nil }
            current = current.appending(path: name)
        }
        return current
    }

    private func listing(of folder: URL) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = listings[folder.path] { return cached }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let map = Dictionary(names.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        listings[folder.path] = map
        return map
    }
}
