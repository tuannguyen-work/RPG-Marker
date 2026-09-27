//
//  CoverExtractor.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Builds a library cover from the game's own artwork: its title screen, or else its icon.
nonisolated enum CoverExtractor {
    /// Longest side of the stored cover, in pixels.
    private static let maxPixelSize = 640

    /// Writes a PNG cover to `destination`. Returns false when the game has no usable artwork
    /// (for example encrypted images), in which case the library shows a built-in cover.
    @discardableResult
    static func writeCover(for engine: GameEngine, contentRoot: URL, to destination: URL) -> Bool {
        guard let image = coverImage(for: engine, contentRoot: contentRoot) else { return false }
        try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(output, image, nil)
        return CGImageDestinationFinalize(output)
    }

    private static func coverImage(for engine: GameEngine, contentRoot: URL) -> CGImage? {
        let resolver = CaseInsensitiveResolver(root: contentRoot)
        switch engine {
        case .mv, .mz:
            if let title = mvTitleImage(resolver: resolver, contentRoot: contentRoot) { return title }
            return resolver.resolve("icon/icon.png").flatMap(thumbnail)
        case .xp, .vx, .vxAce:
            // The title name lives in Ruby-serialized data; these folders usually hold just that image.
            // VX Ace: Graphics/Titles1, XP: Graphics/Titles, VX: Graphics/System/Title.png.
            for folder in ["Graphics/Titles1", "Graphics/Titles"] {
                if let image = firstImage(in: resolver.resolve(folder)).flatMap(thumbnail) { return image }
            }
            return ["png", "jpg", "bmp"].lazy.compactMap { resolver.resolve("Graphics/System/Title.\($0)") }.first.flatMap(thumbnail)
        }
    }

    private static func firstImage(in directory: URL?) -> URL? {
        guard let directory else { return nil }
        return ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["png", "jpg", "jpeg", "bmp"].contains($0.pathExtension.lowercased()) }
            .min { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The title screen as the game draws it: `title1Name` with the `title2Name` frame on top.
    private static func mvTitleImage(resolver: CaseInsensitiveResolver, contentRoot: URL) -> CGImage? {
        guard let systemURL = resolver.resolve("data/System.json"),
              let data = try? Data(contentsOf: systemURL),
              let system = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title1 = system["title1Name"] as? String, !title1.isEmpty else {
            return nil
        }
        let cipher = RPGMakerCipher(contentRoot: contentRoot)
        guard let background = image(named: "img/titles1/\(title1)", resolver: resolver, cipher: cipher) else { return nil }
        guard let title2 = system["title2Name"] as? String, !title2.isEmpty,
              let frame = image(named: "img/titles2/\(title2)", resolver: resolver, cipher: cipher) else {
            return background
        }
        return composite(background, frame)
    }

    /// A PNG by name without extension: plain, or encrypted by deployment (MV .rpgmvp, MZ .png_).
    private static func image(named name: String, resolver: CaseInsensitiveResolver, cipher: RPGMakerCipher?) -> CGImage? {
        if let url = resolver.resolve(name + ".png") { return thumbnail(url) }
        guard let cipher else { return nil }
        for encryptedExtension in ["rpgmvp", "png_"] {
            if let url = resolver.resolve("\(name).\(encryptedExtension)"),
               let encrypted = try? Data(contentsOf: url),
               let png = cipher.decrypt(encrypted),
               let source = CGImageSourceCreateWithData(png as CFData, nil) {
                return thumbnail(source)
            }
        }
        return nil
    }

    private static func thumbnail(_ url: URL) -> CGImage? {
        CGImageSourceCreateWithURL(url as CFURL, nil).flatMap(thumbnail)
    }

    private static func thumbnail(_ source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func composite(_ background: CGImage, _ overlay: CGImage) -> CGImage? {
        let size = CGSize(width: background.width, height: background.height)
        guard let context = CGContext(
            data: nil, width: background.width, height: background.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return background }
        context.draw(background, in: CGRect(origin: .zero, size: size))
        context.draw(overlay, in: CGRect(origin: .zero, size: size))
        return context.makeImage() ?? background
    }
}
