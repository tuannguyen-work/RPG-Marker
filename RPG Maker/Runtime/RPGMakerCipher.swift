//
//  RPGMakerCipher.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

/// The asset format RPG Maker MV/MZ writes when a game is deployed with "encrypt images/audio":
/// a fixed 16-byte header, then the original file with its first 16 bytes XORed with the key
/// stored in the game's own data/System.json.
///
/// The engine undoes this itself while playing. The app only needs it where it handles assets
/// before the engine does: library covers, and converting MV's Ogg audio to WAV for iOS. It is
/// never used to export assets.
nonisolated struct RPGMakerCipher {
    /// "RPGMV" signature, version 000301, padding (Decrypter.SIGNATURE + VER + REMAIN).
    static let header = Data([0x52, 0x50, 0x47, 0x4D, 0x56, 0x00, 0x00, 0x00, 0x00, 0x03, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00])

    /// Encrypted extension → original extension (MV and MZ spellings).
    static let encryptedExtensions: [String: String] = [
        "rpgmvp": "png", "rpgmvo": "ogg", "rpgmvm": "m4a",
        "png_": "png", "ogg_": "ogg", "m4a_": "m4a",
    ]

    private let key: [UInt8]

    /// Reads `encryptionKey` from the game's System.json; nil when the game has none.
    init?(contentRoot: URL) {
        guard let url = CaseInsensitiveResolver(root: contentRoot).resolve("data/System.json"),
              let data = try? Data(contentsOf: url),
              let system = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hex = system["encryptionKey"] as? String else { return nil }
        self.init(hexKey: hex)
    }

    init?(hexKey: String) {
        var bytes: [UInt8] = []
        var index = hexKey.startIndex
        while index < hexKey.endIndex, bytes.count < 16 {
            let next = hexKey.index(index, offsetBy: 2, limitedBy: hexKey.endIndex) ?? hexKey.endIndex
            guard let byte = UInt8(hexKey[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        guard bytes.count == 16 else { return nil }
        key = bytes
    }

    static func isEncrypted(_ data: Data) -> Bool {
        data.prefix(header.count) == header
    }

    func decrypt(_ data: Data) -> Data? {
        guard Self.isEncrypted(data), data.count >= Self.header.count + key.count else { return nil }
        var body = Data(data.dropFirst(Self.header.count))
        xor(&body)
        return body
    }

    func encrypt(_ data: Data) -> Data {
        var body = data
        xor(&body)
        return Self.header + body
    }

    private func xor(_ data: inout Data) {
        for offset in 0..<min(key.count, data.count) {
            data[data.startIndex + offset] ^= key[offset]
        }
    }
}
