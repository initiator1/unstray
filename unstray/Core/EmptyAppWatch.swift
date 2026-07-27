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

    /// Called when an app came forward and still has nothing to show, after we
    /// have already tried and failed to fix it.
    var onUnfixable: ((String) -> Void)?

    private var pending: DispatchWorkItem?

    /// Anything shorter than this is a toolbar, a menu-bar strip, or a shadow —
    /// not a window you were trying to look at. CotEditor's leftovers were 26pt.
    private let smallestRealWindow: CGFloat = 120

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
        guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
                  as? [[String: Any]]
        else { return false }

        for w in list {
            guard let owner = w[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
                  let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let h = b["Height"], let width = b["Width"],
                  let x = b["X"], let y = b["Y"]
            else { continue }

            // Toolbars and menu-bar strips do not count as something to look at.
            guard h >= smallestRealWindow, width >= 200 else { continue }

            let r = CGRect(x: x, y: y, width: width, height: h)
            if screens.contains(where: { $0.intersects(r) }) {
                return false        // found something real and reachable
            }
        }
        return true
    }

    private func checkAndRepair(_ app: NSRunningApplication) {
        // Only worry about the app that is actually in front right now. If the
        // person has moved on, the moment has passed.
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier
                == app.processIdentifier,
              showsNothing(pid: app.processIdentifier)
        else { return }

        let name = app.localizedName ?? "That app"
        RepairLog.write(event: "app_showed_nothing", detail: ["fixing": true])

        // Ask the app to open a window, the same way the Dock is supposed to.
        // This is the only repair that helps here: there is no window to move,
        // so the app has to be persuaded to make one.
        let asked = AppReopen.ask(app)

        // Give it a moment, then see whether anything actually appeared.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if self.showsNothing(pid: app.processIdentifier) {
                RepairLog.write(event: "app_showed_nothing_unfixed",
                                detail: ["asked": asked])
                self.onUnfixable?(name)
            } else {
                RepairLog.write(event: "app_showed_nothing_fixed", detail: [:])
            }
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
        return ask(app)
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
