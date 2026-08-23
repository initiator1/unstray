import Cocoa

/// Opens the system-owned Force Quit Applications window without quitting an
/// app on the person's behalf. System Events needs Automation permission to
/// send the same key press a person would use.
enum ForceQuitWindow {
    private static let activityMonitor = URL(
        fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"
    )

    static func open() -> Bool {
        let countBefore = loginWindowCount()
        var error: NSDictionary?
        let source = """
        tell application "System Events" to key code 53 using {command down, option down}
        """
        NSAppleScript(source: source)?.executeAndReturnError(&error)

        let deadline = Date().addingTimeInterval(1.5)
        var opened = false
        repeat {
            if loginWindowCount() > countBefore {
                opened = true
                break
            }
            if Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        } while Date() < deadline

        if !opened {
            NSWorkspace.shared.open(activityMonitor)
        }
        RepairLog.write(event: "force_quit_window", detail: ["opened": opened])
        return opened
    }

    /// The Force Quit window belongs to loginwindow. Its title is unavailable
    /// without Screen Recording permission, so only the number of visible
    /// windows is compared.
    private static func loginWindowCount() -> Int {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], kCGNullWindowID
        ) as? [[String: Any]] else { return 0 }

        return windows.filter {
            $0[kCGWindowOwnerName as String] as? String == "loginwindow"
        }.count
    }
}
