import Cocoa
import ApplicationServices

/// Whether a person can use an app right now.
///
/// ## The mistake this file corrects
///
/// The first version of unstray asked "does a window exist somewhere in
/// coordinate space?" That is the wrong question, and it let real problems
/// through. CotEditor was clicked in the Dock and showed nothing, but its
/// leftover 26pt menu-bar strips existed, so the scan said everything was fine.
///
/// An app can exist and be hidden, frozen, or still starting. Those app-level
/// questions and their repairs stay here. `WindowUse` owns the window-level
/// question, so every path agrees about what a person can read and click.
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
        /// A window leaves too little on screen to read or click.
        case pushedOffTheEdge(window: AXUIElement, frame: CGRect)
        /// No window worth looking at exists at all.
        case nothingToShow
    }

    /// The first thing wrong with this app, or nil when all is well.
    static func problem(for app: NSRunningApplication) -> Problem? {
        let pid = app.processIdentifier

        // An app told at startup to have no windows is not missing one. It looks
        // identical to the bug from every angle this file can see, and neither
        // repair can possibly work on it. See WindowlessByDesign.
        if WindowlessByDesign.applies(to: app) { return nil }

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

        // Count windows across every process in this app family, so a helper's
        // window rescues the app it belongs to.
        let judged: [(pid: pid_t, report: WindowUse.Report)] =
            relatedPIDs(of: app).flatMap { relatedPID in
                Usability.windows(pid: relatedPID, scope: .oneChosenApp).map {
                    (pid: relatedPID, report: $0)
                }
            }
        let windowReports = judged.filter {
            $0.report.verdict != .notSomethingYouWereWorkingIn
        }

        // Nothing at all to look at.
        guard !windowReports.isEmpty else { return .nothingToShow }

        // Everything is off every screen — the stranded case, handled elsewhere
        // by WindowScan, so not reported again here.
        if windowReports.allSatisfy({ $0.report.verdict == .lostOffEveryScreen }) {
            return .nothingToShow
        }

        // A corner can remain visible while the useful part is gone. This wins
        // over the title-bar question because restoring the whole window fixes
        // both problems with one smaller, clearer repair.
        if !windowReports.contains(where: { $0.report.verdict == .usable }) {
            for stuck in windowReports where stuck.report.verdict == .pushedPastTheEdge {
                if let axWin = matchingAXWindow(pid: stuck.pid,
                                                frame: stuck.report.frame) {
                    return .pushedOffTheEdge(window: axWin,
                                            frame: stuck.report.frame)
                }
            }
        }

        // A window you can see but cannot grab. Only worth reporting when NONE
        // of the visible windows is fully usable.
        if !windowReports.contains(where: { $0.report.verdict == .usable }) {
            for stuck in windowReports where stuck.report.verdict == .titleBarOutOfReach {
                if let axWin = matchingAXWindow(pid: stuck.pid,
                                                frame: stuck.report.frame) {
                    return .titleBarOutOfReach(window: axWin,
                                              frame: stuck.report.frame)
                }
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

    /// Every layer-0 window owned by this process, judged from one list read.
    /// Small leftovers stay in the result because callers need the full set.
    static func windows(pid: pid_t,
                        scope: WindowUse.Scope) -> [WindowUse.Report] {
        guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
                  as? [[String: Any]]
        else { return [] }

        let screens = ScreenSpace.screens()
        var out: [WindowUse.Report] = []
        for w in list {
            guard let owner = w[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
                  let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let h = b["Height"], let width = b["Width"],
                  let x = b["X"], let y = b["Y"]
            else { continue }
            let frame = CGRect(x: x, y: y, width: width, height: h)
            let onThisScreenful = (w[kCGWindowIsOnscreen as String] as? Bool) ?? false
            out.append(WindowUse.judge(frame,
                                       onThisScreenful: onThisScreenful,
                                       screens: screens,
                                       scope: scope))
        }
        return out
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
        let screens = ScreenSpace.usableScreens()
        let screen = screens.first { $0.intersects(frame) }
            ?? WindowScan.screenUnderCursor()
        guard !screen.isNull else { return false }

        // Just far enough in that the whole title bar is on the screen, and no
        // further — a window someone placed deliberately should move as little as
        // possible.
        var p = CGPoint(x: max(frame.minX, screen.minX + 8),
                        y: max(frame.minY, screen.minY + 8))
        guard let v = AXValueCreate(.cgPoint, &p) else { return false }
        return AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, v) == .success
    }

    /// Restores the whole window while preserving every part of its placement
    /// that already fits. This is the quiet repair after a person selects an app.
    @discardableResult
    static func slideFullyIntoView(_ win: AXUIElement, frame: CGRect) -> Bool {
        let screens = ScreenSpace.usableScreens()
        let preferred = WindowScan.screenUnderCursor()
        guard !screens.isEmpty, !preferred.isNull else { return false }
        var p = ScreenSpace.slideIntoView(frame, screens: screens,
                                          preferred: preferred)
        guard let v = AXValueCreate(.cgPoint, &p) else { return false }
        return AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, v) == .success
    }
}
