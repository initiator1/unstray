import Foundation

/// Writes down what was found and what was fixed, one line of JSON per event.
///
/// Two readers:
///   - a future me, working out why something regressed
///   - any assistant tool that wants to know "the Mac hid things again after
///     update" as real context about the day
///
/// Technical detail belongs here, never on screen. Coordinates, defaults keys,
/// and Apple Feedback numbers all live in this file.
enum RepairLog {

    static let url: URL = {
        let dir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".unstray", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("events.jsonl")
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Anything past this and we start again. Without a cap the file grows for
    /// ever, and a log nobody can read is not a log.
    private static let maxBytes = 256 * 1024

    private static func trimIfHuge() {
        guard let a = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = a[.size] as? Int, size > maxBytes else { return }
        // Keep the most recent half; simplest thing that cannot corrupt a line.
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        let kept = lines.suffix(lines.count / 2).joined(separator: "\n") + "\n"
        try? kept.write(to: url, atomically: true, encoding: .utf8)
    }

    static func write(event: String, detail: [String: Any] = [:]) {
        trimIfHuge()
        var row: [String: Any] = [
            "at": iso.string(from: Date()),
            "event": event,
            "os": ProcessInfo.processInfo.operatingSystemVersionString
        ]
        row.merge(detail) { a, _ in a }

        guard let data = try? JSONSerialization.data(withJSONObject: row),
              var line = String(data: data, encoding: .utf8)
        else { return }
        line += "\n"

        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
            // Owner-only: this is a record of your own machine's behaviour and
            // no other account has any business reading it.
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    /// Records WHAT kind of problem was found, never WHICH apps or where.
    ///
    /// An earlier version wrote `technicalNote` straight to disk, which meant
    /// the file accumulated a permanent, timestamped record of which apps you
    /// had open and their positions. Nobody agreed to that, and the permission
    /// screen's promises do not prepare anyone for it. Names and coordinates
    /// now stay in memory and never reach the file.
    static func found(_ findings: [Finding]) {
        guard !findings.isEmpty else { return }
        write(event: "found", detail: [
            "count": findings.count,
            "kinds": findings.map { $0.kind.rawValue }
        ])
    }

    /// Records what the repair DID, not whether it "worked".
    ///
    /// This used to write a `success` flag taken from the repair's own Bool,
    /// and each repair meant something different by that Bool — one of them
    /// reported opening Activity Monitor as a successful repair of a frozen
    /// app. The flag is gone rather than renamed, because no reader could tell
    /// which meaning any given line carried.
    static func repaired(_ f: Finding, outcome: RepairOutcome) {
        write(event: "repaired", detail: [
            "kind": f.kind.rawValue,
            "outcome": outcome.rawValue,
            "neededLogout": f.costWarning != nil
        ])
    }

    /// How many windows moved, against how many were reported. They are allowed
    /// to differ — an app can put a window back on its own, and a window one
    /// screenful away can go out of reach between the scan and the button.
    static func rescued(moved: Int, reported: Int) {
        write(event: "rescued", detail: ["moved": moved, "reported": reported])
    }
}
