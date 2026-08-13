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
    ///
    /// Counts every process in the app's family, not just the one that came
    /// forward. Electron and Steam-style apps keep the real window in a helper
    /// with a different pid, and asking only about the main process reports an
    /// app as empty while its window is sitting right there.
    private func showsNothing(_ app: NSRunningApplication) -> Bool {
        let screens = ScreenSpace.screens()
        let windows = Usability.relatedPIDs(of: app).flatMap { Usability.realWindows(pid: $0) }
        return !windows.contains {
            !ScreenSpace.visiblePart(of: $0, screens: screens).isNull
        }
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

        case .pushedOffTheEdge(let win, let frame):
            // Selecting the app is already a request to use this window. Restore
            // the whole shape and speak only when the quiet repair does not land.
            Usability.slideFullyIntoView(win, frame: frame)
            confirm(app, name: name, problem: problem)

        case .notResponding:
            // The most cautious case, not the least.
            //
            // This fired the instant an app stopped answering, which meant it
            // accused Claude of being frozen during its own "Restart to Update"
            // — the app came back a second later. An app that is launching,
            // relaunching, or briefly busy looks exactly like a frozen one at any
            // single instant. The difference is only visible over time.
            //
            // So: watch it for several seconds and only speak if it never
            // recovers. Nothing can be done about a frozen app anyway, so there
            // is no cost to waiting and a real cost to being wrong.
            watchForRecovery(app, name: name)

        case .nothingToShow:
            // The same caution as a frozen app, for the same reason: an app that
            // is launching or relaunching has no window yet, and at any single
            // instant that is identical to the bug. How patient to be, and
            // why, is in EmptyAppPatience.
            watchForWindow(app, name: name)
        }
    }

    /// Watches an app that came forward with nothing to show, and speaks only
    /// once every ordinary explanation has been ruled out. `EmptyAppPatience`
    /// makes the decision on each look; this only carries it out.
    private func watchForWindow(_ app: NSRunningApplication, name: String,
                                looksSoFar: Int = 0, askedAt: Date? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + EmptyAppPatience.lookAgainEvery) { [weak self] in
            guard let self else { return }

            let decision = EmptyAppPatience.step(
                terminated: app.isTerminated,
                showsSomethingNow: !self.showsNothing(app),
                personMovedOn: NSWorkspace.shared.frontmostApplication?.processIdentifier
                    != app.processIdentifier,
                stillStartingUp: Usability.isStillStartingUp(app),
                alreadyAsked: askedAt != nil,
                secondsSinceAsking: askedAt.map { Date().timeIntervalSince($0) } ?? 0,
                looksSoFar: looksSoFar
            )

            switch decision {
            case .goQuiet:
                RepairLog.write(event: app.isTerminated ? "app_unusable_moot"
                                                        : "app_unusable_fixed",
                                detail: ["problem": "nothingToShow",
                                         "looks": looksSoFar])

            case .keepWaiting:
                self.watchForWindow(app, name: name,
                                    looksSoFar: looksSoFar + 1, askedAt: askedAt)

            case .askForAWindow:
                // Ask the way the Dock is supposed to, then fall back to asking
                // for a blank document, which works on apps that swallow the
                // reopen event.
                var asked = AppReopen.ask(app)
                if self.showsNothing(app) {
                    asked = AppReopen.askForNewDocument(app) || asked
                }
                _ = asked
                self.watchForWindow(app, name: name,
                                    looksSoFar: looksSoFar + 1, askedAt: Date())

            case .speak:
                RepairLog.write(event: "app_unusable_unfixed",
                                detail: ["problem": "nothingToShow",
                                         "looks": looksSoFar])
                self.onUnfixable?(name, .nothingToShow)
            }
        }
    }

    /// Watches an app that stopped answering, and only speaks if it stays that
    /// way. A frozen app is frozen persistently; a restarting one is not.
    private func watchForRecovery(_ app: NSRunningApplication, name: String,
                                  checksLeft: Int = 5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }

            // It quit, or it came back. Either way there is nothing to say.
            guard !app.isTerminated else {
                RepairLog.write(event: "app_unusable_moot", detail: ["reason": "quit"])
                return
            }
            if Usability.isResponding(pid: app.processIdentifier) {
                RepairLog.write(event: "app_unusable_fixed",
                                detail: ["problem": "notResponding", "note": "recovered"])
                return
            }

            // Still not answering. Keep waiting, up to about six seconds.
            guard checksLeft > 0 else {
                // Only bother them if they are still looking at it.
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier
                        == app.processIdentifier else { return }
                RepairLog.write(event: "app_unusable_unfixed",
                                detail: ["problem": "notResponding"])
                self.onUnfixable?(name, .notResponding)
                return
            }
            self.watchForRecovery(app, name: name, checksLeft: checksLeft - 1)
        }
    }

    /// Looks again after a moment. Silence if the repair worked; an explanation
    /// if it did not.
    private func confirm(_ app: NSRunningApplication, name: String,
                         problem: Usability.Problem) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }

            // The same two ordinary explanations as everywhere else: it quit, or
            // it is still coming up. Neither is a thing to tell someone about,
            // and a dead process answers every question wrongly.
            guard !app.isTerminated, !Usability.isStillStartingUp(app) else {
                RepairLog.write(event: "app_unusable_moot",
                                detail: ["problem": self.label(problem),
                                         "reason": app.isTerminated ? "quit" : "still opening"])
                return
            }

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
        case .pushedOffTheEdge:     return "pushedOffTheEdge"
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
    /// ## Why this is a last resort, not a normal repair
    ///
    /// This creates a REAL document. In TextEdit that means an untitled file that
    /// later asks "do you want to keep this?" when the person quits — a dialog
    /// about something they never created. Leaving debris in someone's app to fix
    /// a window bug is a worse outcome than the bug.
    ///
    /// So it is only used when the polite request has already failed, and only
    /// for apps where a blank document is genuinely harmless. Apps that treat a
    /// new document as a side effect worth confirming are excluded.
    @discardableResult
    static func askForNewDocument(_ app: NSRunningApplication) -> Bool {
        guard let name = app.localizedName else { return false }

        // Apps where a stray untitled document is a nuisance rather than a
        // rescue: they prompt to save it, so the person ends up dealing with a
        // file they never made. Better to explain the problem than create one.
        let leavesDebris: Set<String> = [
            "TextEdit", "Pages", "Numbers", "Keynote", "Preview",
            "Script Editor", "CotEditor", "BBEdit", "Xcode"
        ]
        guard !leavesDebris.contains(name) else { return false }

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
