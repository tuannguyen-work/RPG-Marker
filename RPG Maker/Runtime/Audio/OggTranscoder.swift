//
//  OggTranscoder.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import CryptoKit
import Foundation

/// Converts Ogg Vorbis files to WAV for engines that can't decode Vorbis on iOS.
///
/// RPG Maker MV asks for .m4a on mobile devices and has no Vorbis decoder of its own, while many PC
/// releases only ship .ogg. WebKit decodes WAV, so those files are decoded with stb_vorbis and cached.
nonisolated enum OggTranscoder {
    struct Output {
        let wav: Data
        let sampleRate: Int
        /// RPG Maker loop points from the Ogg comments, in samples.
        let loopStart: Int?
        let loopLength: Int?
    }

    enum Failure: Error {
        case decodingFailed
    }

    private static let cacheDirectory = URL.cachesDirectory.appending(path: "TranscodedAudio", directoryHint: .isDirectory)

    static func wav(fromOgg url: URL) throws -> Output {
        try wav(fromOgg: Data(contentsOf: url, options: .mappedIfSafe), identity: url)
    }

    /// `identity` is the file the data came from (possibly encrypted); it keys the cache.
    static func wav(fromOgg ogg: Data, identity url: URL) throws -> Output {
        let loop = loopPoints(in: ogg)
        let cached = cacheDirectory.appending(path: try cacheKey(for: url) + ".wav")

        if let wav = try? Data(contentsOf: cached, options: .mappedIfSafe), wav.count > 44 {
            return Output(wav: wav, sampleRate: Int(readUInt32(wav, at: 24)), loopStart: loop.start, loopLength: loop.length)
        }

        var channels: Int32 = 0
        var sampleRate: Int32 = 0
        var samples: UnsafeMutablePointer<Int16>?
        let frames = ogg.withUnsafeBytes { buffer in
            stb_vorbis_decode_memory(buffer.bindMemory(to: UInt8.self).baseAddress, Int32(buffer.count), &channels, &sampleRate, &samples)
        }
        guard frames > 0, let samples, channels > 0 else { throw Failure.decodingFailed }
        defer { free(samples) }

        let pcm = Data(bytes: samples, count: Int(frames) * Int(channels) * MemoryLayout<Int16>.size)
        let wav = wavHeader(dataSize: pcm.count, channels: Int(channels), sampleRate: Int(sampleRate)) + pcm

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? wav.write(to: cached, options: .atomic)
        return Output(wav: wav, sampleRate: Int(sampleRate), loopStart: loop.start, loopLength: loop.length)
    }

    // MARK: - Helpers

    /// Path + size + modification date, so a replaced file is decoded again.
    private static func cacheKey(for url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let identity = "\(url.path)|\(values.fileSize ?? 0)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
        return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Reads LOOPSTART / LOOPLENGTH from the Vorbis comment header near the start of the file.
    static func loopPoints(in ogg: Data) -> (start: Int?, length: Int?) {
        let header = String(decoding: ogg.prefix(64 * 1024), as: UTF8.self)
        func value(_ name: String) -> Int? {
            guard let range = header.range(of: name + "=") else { return nil }
            return Int(header[range.upperBound...].prefix(while: \.isNumber))
        }
        return (value("LOOPSTART"), value("LOOPLENGTH"))
    }

    private static func wavHeader(dataSize: Int, channels: Int, sampleRate: Int) -> Data {
        var header = Data()
        func append(_ value: some FixedWidthInteger) {
            withUnsafeBytes(of: value.littleEndian) { header.append(contentsOf: $0) }
        }
        let bytesPerSample = 2
        header.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize))
        header.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))                                        // fmt chunk size
        append(UInt16(1))                                         // PCM
        append(UInt16(channels))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * channels * bytesPerSample))    // byte rate
        append(UInt16(channels * bytesPerSample))                 // block align
        append(UInt16(8 * bytesPerSample))                        // bits per sample
        header.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize))
        return header
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 | UInt32(data[data.startIndex + offset + $1]) << (8 * $1) }
    }
}
