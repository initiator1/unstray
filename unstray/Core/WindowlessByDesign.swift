import Cocoa

/// Whether a process was started on the explicit instruction to have no windows.
///
/// ## The false alarm this removes
///
/// unstray already ignores menu-bar helpers, because they have no windows by
/// design and reporting them produced eight "problems" that were all nothing.
/// That filter reads `activationPolicy`, and it misses an entire second family:
/// a browser started with `--headless`.
///
/// A headless Chrome is a full application by every measure unstray uses. It has
/// a Dock icon, it takes the menu bar when something activates it, and it has no
/// windows — permanently, on purpose. So the check fires, both repairs are
/// attempted, and both must fail:
///
/// - the reopen event is accepted and ignored, because headless means headless;
/// - `make new document` fails outright, because Chrome has no documents.
///
/// unstray then tells the person their browser is broken and offers a button
/// that cannot ever work. That is the exact failure this app exists to remove.
///
/// Observed on 2026-08-13. An automation script left a headless Chrome running
/// with a temporary profile. macOS routed a clicked link to it, because it was
/// the registered `com.google.Chrome`, and the link went nowhere. The person saw
/// "Chrome" in the menu bar with nothing on screen, which is the real bug's
/// signature exactly, and unstray could neither fix it nor stop reporting it.
///
/// ## Why only true headless flags count
///
/// `--no-startup-window` is deliberately NOT in this list. It means "open no
/// window *at launch*", not "never have a window". Such an app opens one
/// perfectly well when asked, so a person clicking it and seeing nothing IS the
/// bug, and the ordinary repair does work. Suppressing it would hide a real
/// problem instead of a fake one.
enum WindowlessByDesign {

    /// Started with an instruction that rules out windows for the whole life of
    /// the process. Everything else is a normal app having a bad day.
    ///
    /// Chromium, Electron and Edge take `--headless`, optionally with a mode
    /// (`--headless=new`). Firefox accepts a single dash as well.
    static func launchedWithoutWindows(argv: [String]) -> Bool {
        argv.contains { arg in
            arg == "--headless" || arg == "-headless"
                || arg.hasPrefix("--headless=") || arg.hasPrefix("-headless=")
        }
    }

    /// True when this app can never show the person anything, so nothing about
    /// it is worth reporting or repairing.
    static func applies(to app: NSRunningApplication) -> Bool {
        launchedWithoutWindows(argv: arguments(of: app.processIdentifier))
    }

    /// The command line another process was started with.
    ///
    /// `KERN_PROCARGS2` is the supported way to read this and needs no special
    /// permission for a process owned by the same person. The buffer holds the
    /// argument count, then the executable path, then the arguments, all
    /// null-separated, so the path is dropped and exactly `argc` values are
    /// taken — reading past them runs into the environment, where a variable
    /// could contain anything and produce a false match.
    static func arguments(of pid: pid_t) -> [String] {
        var size = 0
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]

        // Ask for the size first; the command line has no fixed length.
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size
        else { return [] }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }

        var argc: Int32 = 0
        withUnsafeMutableBytes(of: &argc) { out in
            buffer.withUnsafeBytes { raw in
                out.copyMemory(from: UnsafeRawBufferPointer(rebasing: raw[0..<4]))
            }
        }
        guard argc > 0 else { return [] }

        // Split what follows the count into null-separated pieces.
        let bytes = buffer[MemoryLayout<Int32>.size..<size].map { UInt8(bitPattern: $0) }
        var pieces: [String] = []
        var current: [UInt8] = []
        for byte in bytes {
            if byte == 0 {
                if !current.isEmpty {
                    pieces.append(String(decoding: current, as: UTF8.self))
                    current = []
                }
            } else {
                current.append(byte)
            }
        }
        if !current.isEmpty { pieces.append(String(decoding: current, as: UTF8.self)) }

        // The first piece is the executable path, which is not an argument, and
        // only `argc` arguments follow it.
        guard pieces.count > 1 else { return [] }
        return Array(pieces.dropFirst().prefix(Int(argc)))
    }
}
