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
            .appendingPathComponent(".foremac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("events.jsonl")
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func write(event: String, detail: [String: Any] = [:]) {
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
        }
    }

    static func found(_ findings: [Finding]) {
        guard !findings.isEmpty else { return }
        write(event: "found", detail: [
            "count": findings.count,
            "kinds": findings.map { $0.kind.rawValue },
            "notes": findings.map { $0.technicalNote }
        ])
    }

    static func repaired(_ f: Finding, success: Bool) {
        write(event: "repaired", detail: [
            "kind": f.kind.rawValue,
            "success": success,
            "note": f.technicalNote,
            "neededLogout": f.costWarning != nil
        ])
    }

    static func rescued(count: Int) {
        write(event: "rescued", detail: ["windows": count])
    }
}
