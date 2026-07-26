import Cocoa

/// Remembers which app the person was actually using.
///
/// ## Why this exists
///
/// When someone presses the rescue key, we have to know what they were trying
/// to reach. Asking macOS for the frontmost app does not work:
///
///   - Pressing the key can make *us* frontmost, so we would rescue ourselves.
///   - The app they want often has no visible window at all — that is precisely
///     why they pressed the key — so it may never have become frontmost.
///
/// So instead of asking at the moment of the key press, we quietly keep note of
/// every app they switch to, and ignore ourselves. The most recent one is the
/// app they are fighting with.
///
/// This is not surveillance and it is not stored: one process id, held in
/// memory, replaced each time they switch, gone when the app quits. Nothing is
/// written to disk and no window contents are ever read.
final class ActivityWatch {
    static let shared = ActivityWatch()

    /// The last app the person switched to that was not us.
    private(set) var lastUsedApp: pid_t?

    private var previous: pid_t?

    private init() {}

    func start() {
        // Seed from whatever is in front right now, so the very first key press
        // works even if they have not switched apps since launch.
        if let f = NSWorkspace.shared.frontmostApplication,
           f.processIdentifier != getpid() {
            lastUsedApp = f.processIdentifier
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                      as? NSRunningApplication
            else { return }

            let pid = app.processIdentifier
            guard pid != getpid() else { return }   // never count ourselves

            self.previous = self.lastUsedApp
            self.lastUsedApp = pid
        }
    }

    /// The app before the current one. Useful when the person switched to the
    /// app they want, saw nothing, and then reached for the key.
    var priorApp: pid_t? { previous }
}
