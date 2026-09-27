//
//  ZipArchive.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Compression
import Foundation

/// Minimal read-only ZIP reader: stored and deflate entries, ZIP64, streamed to disk.
///
/// Written in-house instead of pulling a dependency because RPG Maker games from Japan are often
/// zipped on Windows with Shift-JIS file names and no UTF-8 flag, which most ZIP libraries mangle.
nonisolated struct ZipArchive {
    struct Entry {
        /// Sanitized relative path, "/"-separated, never containing "..".
        let path: String
        let isDirectory: Bool
        let method: UInt16
        let isEncrypted: Bool
        let compressedSize: UInt64
        let uncompressedSize: UInt64
        let localHeaderOffset: UInt64
    }

    enum Error: Swift.Error, Equatable {
        case notAZip
        case corrupt
        case encrypted
        case unsupportedCompression(UInt16)
    }

    let url: URL
    let entries: [Entry]

    init(url: URL) throws {
        self.url = url
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        entries = try Self.readCentralDirectory(handle)
    }

    /// Extracts every entry below `destination`. `progress` receives 0...1, at most once per percent.
    func extract(to destination: URL, progress: (Double) -> Void = { _ in }) throws {
        let fileManager = FileManager.default
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let total = max(entries.reduce(0) { $0 + $1.compressedSize }, 1)
        var processed: UInt64 = 0
        var lastReported = -1

        for entry in entries where !Self.isJunk(entry.path) {
            let target = destination.appending(path: entry.path, directoryHint: entry.isDirectory ? .isDirectory : .notDirectory)
            if entry.isDirectory {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
                continue
            }
            guard !entry.isEncrypted else { throw Error.encrypted }
            guard entry.method == 0 || entry.method == 8 else { throw Error.unsupportedCompression(entry.method) }

            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fileManager.createFile(atPath: target.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            let output = try FileHandle(forWritingTo: target)
            defer { try? output.close() }

            // The local header's name/extra lengths can differ from the central directory's.
            try handle.seek(toOffset: entry.localHeaderOffset)
            guard let header = try handle.read(upToCount: 30), header.count == 30,
                  Self.uint32(header, 0) == 0x0403_4B50 else { throw Error.corrupt }
            let dataStart = entry.localHeaderOffset + 30 + UInt64(Self.uint16(header, 26)) + UInt64(Self.uint16(header, 28))
            try handle.seek(toOffset: dataStart)

            var written: UInt64 = 0
            let inflater = entry.method == 8
                ? try OutputFilter(.decompress, using: .zlib) { data in
                    guard let data else { return }
                    try output.write(contentsOf: data)
                    written += UInt64(data.count)
                }
                : nil

            var remaining = entry.compressedSize
            while remaining > 0 {
                guard let chunk = try handle.read(upToCount: Int(min(remaining, 1 << 20))), !chunk.isEmpty else {
                    throw Error.corrupt
                }
                remaining -= UInt64(chunk.count)
                if let inflater {
                    try inflater.write(chunk)
                } else {
                    try output.write(contentsOf: chunk)
                    written += UInt64(chunk.count)
                }
                processed += UInt64(chunk.count)
                let percent = Int(processed * 100 / total)
                if percent != lastReported {
                    lastReported = percent
                    progress(Double(percent) / 100)
                }
            }
            try inflater?.finalize()
            guard written == entry.uncompressedSize else { throw Error.corrupt }
        }
        progress(1)
    }

    // MARK: - Central directory

    private static func readCentralDirectory(_ handle: FileHandle) throws -> [Entry] {
        let fileSize = try handle.seekToEnd()
        let tailLength = min(fileSize, 22 + 0xFFFF)
        try handle.seek(toOffset: fileSize - tailLength)
        let tail = try handle.read(upToCount: Int(tailLength)) ?? Data()

        guard let eocd = lastIndex(of: 0x0605_4B50, in: tail) else { throw Error.notAZip }
        var entryCount = UInt64(uint16(tail, eocd + 10))
        var directorySize = UInt64(uint32(tail, eocd + 12))
        var directoryOffset = UInt64(uint32(tail, eocd + 16))

        if entryCount == 0xFFFF || directorySize == 0xFFFF_FFFF || directoryOffset == 0xFFFF_FFFF {
            // ZIP64: the locator sits right before the classic end-of-central-directory record.
            guard eocd >= 20, uint32(tail, eocd - 20) == 0x0706_4B50 else { throw Error.corrupt }
            try handle.seek(toOffset: uint64(tail, eocd - 20 + 8))
            guard let record = try handle.read(upToCount: 56), record.count == 56,
                  uint32(record, 0) == 0x0606_4B50 else { throw Error.corrupt }
            entryCount = uint64(record, 32)
            directorySize = uint64(record, 40)
            directoryOffset = uint64(record, 48)
        }

        guard directoryOffset + directorySize <= fileSize else { throw Error.corrupt }
        try handle.seek(toOffset: directoryOffset)
        let directory = try handle.read(upToCount: Int(directorySize)) ?? Data()
        guard directory.count == directorySize else { throw Error.corrupt }

        var entries: [Entry] = []
        entries.reserveCapacity(Int(min(entryCount, 100_000)))
        var position = 0
        for _ in 0..<entryCount {
            guard position + 46 <= directory.count, uint32(directory, position) == 0x0201_4B50 else {
                throw Error.corrupt
            }
            let flags = uint16(directory, position + 8)
            let method = uint16(directory, position + 10)
            var compressedSize = UInt64(uint32(directory, position + 20))
            var uncompressedSize = UInt64(uint32(directory, position + 24))
            let nameLength = Int(uint16(directory, position + 28))
            let extraLength = Int(uint16(directory, position + 30))
            let commentLength = Int(uint16(directory, position + 32))
            var localHeaderOffset = UInt64(uint32(directory, position + 42))

            let nameStart = position + 46
            let extraStart = nameStart + nameLength
            let next = extraStart + extraLength + commentLength
            guard next <= directory.count else { throw Error.corrupt }

            // ZIP64 extra field (0x0001) holds the real values for fields saturated at 0xFFFFFFFF.
            var extra = extraStart
            while extra + 4 <= extraStart + extraLength {
                let id = uint16(directory, extra)
                let size = Int(uint16(directory, extra + 2))
                if id == 0x0001 {
                    var field = extra + 4
                    if uncompressedSize == 0xFFFF_FFFF { uncompressedSize = uint64(directory, field); field += 8 }
                    if compressedSize == 0xFFFF_FFFF { compressedSize = uint64(directory, field); field += 8 }
                    if localHeaderOffset == 0xFFFF_FFFF { localHeaderOffset = uint64(directory, field) }
                }
                extra += 4 + size
            }

            let rawName = decodeName(directory.subdata(in: directory.startIndex + nameStart ..< directory.startIndex + extraStart),
                                     isUTF8: flags & (1 << 11) != 0)
            if let path = sanitize(rawName) {
                entries.append(Entry(
                    path: path,
                    isDirectory: rawName.hasSuffix("/") || rawName.hasSuffix("\\"),
                    method: method,
                    isEncrypted: flags & 1 != 0,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeaderOffset
                ))
            }
            position = next
        }
        return entries
    }

    // MARK: - Names

    private static let cp437 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.dosLatinUS.rawValue)))

    /// UTF-8 when flagged or valid, then Shift-JIS (Japanese Windows), then the ZIP default CP437.
    static func decodeName(_ data: Data, isUTF8: Bool) -> String {
        if let name = String(data: data, encoding: .utf8) { return name }
        if !isUTF8, let name = String(data: data, encoding: .shiftJIS) { return name }
        return String(data: data, encoding: cp437) ?? String(decoding: data, as: UTF8.self)
    }

    /// Rejects absolute paths and "..", so an archive can never write outside the destination.
    static func sanitize(_ name: String) -> String? {
        let components = name
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .filter { $0 != "." }
        guard !components.isEmpty, !components.contains("..") else { return nil }
        return components.joined(separator: "/")
    }

    private static func isJunk(_ path: String) -> Bool {
        path.hasPrefix("__MACOSX/") || path == "__MACOSX" || path.hasSuffix(".DS_Store")
    }

    // MARK: - Little-endian helpers

    private static func lastIndex(of signature: UInt32, in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        for index in stride(from: data.count - 22, through: 0, by: -1) where uint32(data, index) == signature {
            return index
        }
        return nil
    }

    private static func integer<T: FixedWidthInteger>(_ data: Data, _ offset: Int) -> T {
        var value: T = 0
        for byte in 0..<MemoryLayout<T>.size {
            value |= T(data[data.startIndex + offset + byte]) << (8 * byte)
        }
        return value
    }

    private static func uint16(_ data: Data, _ offset: Int) -> UInt16 { integer(data, offset) }
    private static func uint32(_ data: Data, _ offset: Int) -> UInt32 { integer(data, offset) }
    private static func uint64(_ data: Data, _ offset: Int) -> UInt64 { integer(data, offset) }
}
