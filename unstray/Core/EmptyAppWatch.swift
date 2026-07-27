import Cocoa
import ApplicationServices

/// Notices when you switch to an app and nothing appears, and asks the app to
/// show you something.
///
/// ## Why this exists
///
/// This is Apple's FB21087054, and it is the most common form of the bug this
/// whole app is about. You click an app. Its name appears in the bar at the top,
/// so it clearly heard you. But no window arrives, because the app has no window
/// open and macOS forgot to ask it to make one.
///
/// An earlier version of unstray missed this completely. It only looked for
/// windows sitting *outside* your screens, so an app with no windows at all
/// looked perfectly healthy and unstray said "all clear" while the person stared
/// at nothing. That was the app failing its own promise.
///
/// ## Why it acts without asking
///
/// Clicking an app *is* the request. Nobody clicks an app icon and then wants to
/// be asked whether they would like to see it. So this repairs silently and only
/// speaks if the repair does not work.
final class EmptyAppWatch {

    /// Called when an app came forward and we could not make it usable.
    /// Carries the app's name and what is wrong, so the panel can explain it.
    var onUnfixable: ((String, Usability.Problem) -> Void)?

    private var pending: DispatchWorkItem?

    /// Long enough for an app that is genuinely opening a window to finish, short
    /// enough that a person has not yet decided the computer is broken.
    private let settleDelay: TimeInterval = 0.7

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                      as? NSRunningApplication
            else { return }
            self.appCameForward(app)
        }
    }

    private func appCameForward(_ app: NSRunningApplication) {
        // Only apps that appear in the bar at the bottom. Menu-bar helpers have
        // no windows by design and must never be "fixed".
        guard app.activationPolicy == .regular,
              app.processIdentifier != getpid()
        else { return }

        // One check at a time: switching apps quickly should not queue up work.
        pending?.cancel()
        let job = DispatchWorkItem { [weak self] in
            self?.checkAndRepair(app)
        }
        pending = job
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay, execute: job)
    }

    /// True when this app has nothing on screen worth looking at.
    private func showsNothing(pid: pid_t) -> Bool {
        let screens = NSScreen.screens.map { $0.frame }
        let windows = Usability.realWindows(pid: pid)
        return !windows.contains { w in screens.contains { $0.intersects(w) } }
    }

    private func checkAndRepair(_ app: NSRunningApplication) {
        // Only worry about the app that is actually in front. If the person has
        // moved on, the moment has passed.
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier
                == app.processIdentifier,
              let problem = Usability.problem(for: app)
        else { return }

        let name = app.localizedName ?? "That app"
        RepairLog.write(event: "app_unusable", detail: ["problem": label(problem)])

        switch problem {

        case .hidden:
            // You pressed Cmd-H, or something did. Clicking the app is a request
            // to see it, so simply unhide it and say nothing.
            app.unhide()
            WindowRescue.bringToFront(pid: app.processIdentifier)
            confirm(app, name: name, problem: problem)

        case .titleBarOutOfReach(let win, let frame):
            // Visible but unmovable. Nudge it down just far enough to grab.
            Usability.bringTitleBarIntoReach(win, frame: frame)
            confirm(app, name: name, problem: problem)

        case .notResponding:
            // Nothing can be done to a frozen app from outside. Say so, because
            // the person is otherwise left clicking a dead icon.
            RepairLog.write(event: "app_unusable_unfixed",
                            detail: ["problem": "notResponding"])
            onUnfixable?(name, problem)

        case .nothingToShow:
            // Ask for a window the way the Dock is supposed to, then fall back to
            // asking for a blank document, which works on apps that swallow the
            // reopen event.
            var asked = AppReopen.ask(app)
            if showsNothing(pid: app.processIdentifier) {
                asked = AppReopen.askForNewDocument(app) || asked
            }
            _ = asked
            confirm(app, name: name, problem: problem)
        }
    }

    /// Looks again after a moment. Silence if the repair worked; an explanation
    /// if it did not.
    private func confirm(_ app: NSRunningApplication, name: String,
                         problem: Usability.Problem) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if Usability.problem(for: app) != nil {
                RepairLog.write(event: "app_unusable_unfixed",
                                detail: ["problem": self.label(problem)])
                self.onUnfixable?(name, problem)
            } else {
                RepairLog.write(event: "app_unusable_fixed",
                                detail: ["problem": self.label(problem)])
            }
        }
    }

    /// Short name for the log. Never shown on screen.
    private func label(_ p: Usability.Problem) -> String {
        switch p {
        case .hidden:              return "hidden"
        case .notResponding:       return "notResponding"
        case .titleBarOutOfReach:  return "titleBarOutOfReach"
        case .nothingToShow:       return "nothingToShow"
        }
    }
}

/// Asks an app to open a window.
///
/// macOS is supposed to do this itself when you click an app with no windows —
/// it sends a "reopen" event, and the app responds by making one. When that goes
/// wrong (FB21087054) we can send the same event ourselves.
enum AppReopen {

    /// Retry path for the on-screen button: find the app again by name, bring it
    /// forward, and ask once more.
    @discardableResult
    static func askByName(_ name: String) -> Bool {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName == name
        }) else { return false }
        WindowRescue.bringToFront(pid: app.processIdentifier)
        if ask(app) { return true }
        return askForNewDocument(app)
    }

    /// Asks a document-based app to make a new, empty document.
    ///
    /// The fallback for apps that swallow the reopen event. Only sent when the
    /// app is already frontmost with nothing on screen, so this cannot surprise
    /// anyone with an unwanted document while they are working.
    @discardableResult
    static func askForNewDocument(_ app: NSRunningApplication) -> Bool {
        guard let name = app.localizedName else { return false }
        let script = "tell application \"\(name)\" to make new document"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        return err == nil
    }

    /// Sends the standard reopen Apple event. Returns whether it was accepted;
    /// the app may still choose to ignore it.
    @discardableResult
    static func ask(_ app: NSRunningApplication) -> Bool {
        // Address the target by process id, which the Apple event system
        // accepts directly.
        var pid = app.processIdentifier
        guard let addr = NSAppleEventDescriptor(
            descriptorType: typeKernelProcessID,
            bytes: &pid,
            length: MemoryLayout.size(ofValue: pid)
        ) else { return false }

        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: addr,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )

        do {
            try event.sendEvent(options: [.noReply], timeout: 2.0)
            return true
        } catch {
            return false
        }
    }
}
