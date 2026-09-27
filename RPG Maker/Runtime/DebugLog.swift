//
//  DebugLog.swift
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

import Foundation

/// DEBUG builds only: appends runtime messages to Library/Caches/runtime.log for inspection from the simulator.
nonisolated enum DebugLog {
    #if DEBUG
    private static let lock = NSLock()
    private static let url = URL.cachesDirectory.appending(path: "runtime.log")
    #endif

    static func write(_ message: String) {
        #if DEBUG
        lock.withLock {
            let line = Data("\(Date.now.formatted(.iso8601)) \(message)\n".utf8)
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: line)
                try? handle.close()
            } else {
                try? line.write(to: url)
            }
        }
        #endif
    }
}
