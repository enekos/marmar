import Foundation
import os

/// Lightweight logger. A GUI app launched via `open`/login has no stderr, so the
/// primary channel is a tailable file at ~/Library/Logs/marmar.log; we also mirror
/// to the unified log (Console.app, subsystem "com.eneko.marmar").
///
///   tail -f ~/Library/Logs/marmar.log
///   log stream --predicate 'subsystem == "com.eneko.marmar"'
enum Log {
    private static let osLog = Logger(subsystem: "com.eneko.marmar", category: "dictation")
    private static let queue = DispatchQueue(label: "com.eneko.marmar.log")

    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("marmar.log")
    }()

    private static let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func log(_ message: String) {
        osLog.log("\(message, privacy: .public)")
        let line = stamp.string(from: Date()) + " " + message + "\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(data)
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    /// Print the whole log to stdout (for `marmar --logs`).
    static func dump() {
        if let s = try? String(contentsOf: fileURL, encoding: .utf8) {
            print(s)
        } else {
            print("(no log yet at \(fileURL.path))")
        }
    }

    static var path: String { fileURL.path }
}
