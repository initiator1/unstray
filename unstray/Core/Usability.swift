import Cocoa
import ApplicationServices

/// Whether you can actually *use* an app's windows right now.
///
/// ## The mistake this file corrects
///
/// The first version of unstray asked "does a window exist somewhere in
/// coordinate space?" That is the wrong question, and it let real problems
/// through. CotEditor was clicked in the Dock and showed nothing, but its
/// leftover 26pt menu-bar strips existed, so the scan said everything was fine.
///
/// A window can exist and be hidden. Exist and be frozen. Exist and have its
/// title bar above the top of the screen, so you can see it and cannot move it.
/// Existence is not usability, and only usability matters to a person.
enum Usability {

    /// Why an app has nothing you can use. Ordered so the cheapest, most
    /// certain check comes first.
    enum Problem: Equatable {
        /// You pressed ⌘H, or something did it for you. Easy to fix.
        case hidden
        /// The app has stopped answering. Cannot be fixed, only explained.
        case notResponding
        /// A window is on screen but its title bar is not, so it cannot be moved.
        case titleBarOutOfReach(window: AXUIElement, frame: CGRect)
        /// No window worth looking at exists at all.
        case nothingToShow
    }

    /// Anything shorter than this is a toolbar or a shadow, not something you
    /// were trying to look at. CotEditor's leftovers were 26pt tall.
    static let smallestRealWindow: CGFloat = 120

    /// How tall the grabbable strip at the top of a window is. If none of this is
    /// on a screen, the window cannot be dragged anywhere.
    private static let titleBarHeight: CGFloat = 30

    /// The first thing wrong with this app, or nil when all is well.
    static func problem(for app: NSRunningApplication) -> Problem? {
        let pid = app.processIdentifier

        // Hidden first: it is certain, cheap, and trivially fixable.
        if app.isHidden { return .hidden }

        // Then whether the app is answering at all. A frozen app cannot be asked
        // anything else, so this has to come before any AX work.
        //
        // An app that has only just started is busy, not frozen. Relaunching
        // through something like "Restart to Update" produces a brand new process
        // that cannot answer for a moment, and accusing it of being frozen is both
        // wrong and alarming. Give it room.
        if !isResponding(pid: pid), !isStillStartingUp(app) {
            return .notResponding
        }

        let screens = NSScreen.screens.map { $0.frame }

        // Count windows across every process in this app family, so a helper's
        // window rescues the app it belongs to.
        let windows = relatedPIDs(of: app).flatMap { realWindows(pid: $0) }

        // Nothing at all to look at.
        guard !windows.isEmpty else { return .nothingToShow }

        // Everything is off every screen — the stranded case, handled elsewhere
        // by WindowScan, so not reported again here.
        let onAnyScreen = windows.filter { w in screens.contains { $0.intersects(w) } }
        guard !onAnyScreen.isEmpty else { return .nothingToShow }

        // A window you can see but cannot grab. Only worth reporting when NONE
        // of the visible windows is fully usable.
        let grabbable = onAnyScreen.filter { hasReachableTitleBar($0, screens: screens) }
        if grabbable.isEmpty, let stuck = onAnyScreen.first {
            if let axWin = matchingAXWindow(pid: pid, frame: stuck) {
                return .titleBarOutOfReach(window: axWin, frame: stuck)
            }
        }

        return nil
    }

    // MARK: - The individual questions

    /// True when the app answers an accessibility request promptly.
    ///
    /// This is the public way to ask "is it beachballing?" — Activity Monitor uses
    /// a private window-server check, but a short timeout on a normal request
    /// gets to the same answer.
    static func isResponding(pid: pid_t) -> Bool {
        let ax = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(ax, 0.5)
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &value)
        // .cannotComplete is what a timeout looks like. Other errors mean the app
        // answered something, which is all we are asking about.
        return err != .cannotComplete
    }

    /// True when this app has not been running long enough to judge.
    ///
    /// Covers the launch and relaunch cases, including in-app updaters that quit
    /// and immediately restart themselves.
    static func isStillStartingUp(_ app: NSRunningApplication) -> Bool {
        if !app.isFinishedLaunching { return true }
        guard let started = app.launchDate else { return false }
        return Date().timeIntervalSince(started) < 8
    }

    /// Every process that belongs to the same app as this one.
    ///
    /// Electron, Chromium and Steam-style apps put their real window in a helper
    /// process with a different pid and a different bundle id. Asking "does THIS
    /// pid have a window?" reports the main app as empty while its window sits
    /// right there in the helper — which is exactly what happened with Steam.
    ///
    /// The reliable signal is the bundle path: a helper's bundle lives inside the
    /// main app's bundle, so `Steam Helper.app` is under `Steam/Contents/...`.
    static func relatedPIDs(of app: NSRunningApplication) -> [pid_t] {
        var pids = [app.processIdentifier]
        guard let base = app.bundleURL?.path else { return pids }

        for other in NSWorkspace.shared.runningApplications
        where other.processIdentifier != app.processIdentifier {
            guard let p = other.bundleURL?.path else { continue }
            // Helper inside this app, or this app inside a shared parent bundle.
            if p.hasPrefix(base + "/") || base.hasPrefix(p + "/") {
                pids.append(other.processIdentifier)
            }
        }
        return pids
    }

    /// Windows big enough to be worth looking at, from every screenful.
    static func realWindows(pid: pid_t) -> [CGRect] {
        guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
                  as? [[String: Any]]
        else { return [] }

        var out: [CGRect] = []
        for w in list {
            guard let owner = w[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
                  let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let h = b["Height"], let width = b["Width"],
                  let x = b["X"], let y = b["Y"],
                  h >= smallestRealWindow, width >= 200
            else { continue }
            out.append(CGRect(x: x, y: y, width: width, height: h))
        }
        return out
    }

    /// True when the top strip of the window is somewhere you can reach with the
    /// mouse.
    static func hasReachableTitleBar(_ r: CGRect, screens: [CGRect]) -> Bool {
        let bar = CGRect(x: r.minX, y: r.minY, width: r.width, height: titleBarHeight)
        return screens.contains { $0.intersects(bar) }
    }

    /// Finds the accessibility handle for a window we located by position, since
    /// the two lists share no identifier.
    private static func matchingAXWindow(pid: pid_t, frame: CGRect) -> AXUIElement? {
        let ax = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(ax, 1.0)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &value) == .success,
              let wins = value as? [AXUIElement]
        else { return nil }

        for w in wins {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &posRef) == .success,
                  AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &sizeRef) == .success
            else { continue }
            var p = CGPoint.zero
            var s = CGSize.zero
            AXValueGetValue(posRef as! AXValue, .cgPoint, &p)
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &s)
            // Positions can differ by a point between the two APIs.
            if abs(p.x - frame.minX) < 3, abs(p.y - frame.minY) < 3 { return w }
        }
        return nil
    }

    // MARK: - Repairs

    /// Nudges a window down until its title bar is grabbable again.
    @discardableResult
    static func bringTitleBarIntoReach(_ win: AXUIElement, frame: CGRect) -> Bool {
        let target = NSScreen.screens
            .first { $0.frame.intersects(frame) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
        guard let screen = target else { return false }

        // Just far enough in that the whole title bar is on the screen, and no
        // further — a window someone placed deliberately should move as little as
        // possible.
        var p = CGPoint(x: max(frame.minX, screen.minX + 8),
                        y: max(frame.minY, screen.minY + 8))
        guard let v = AXValueCreate(.cgPoint, &p) else { return false }
        return AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, v) == .success
    }
}
