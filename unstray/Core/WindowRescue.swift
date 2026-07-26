import Cocoa
import ApplicationServices

/// Brings things back that your Mac has put somewhere you cannot reach.
///
/// ## Why this is written the odd way it is
///
/// The obvious modern way to bring an app forward does not work from an app like
/// this one. Apple replaced the old "come to the front" call in macOS 14 with a
/// polite version: the app currently in front has to agree to step aside. An app
/// sitting in the menu bar is never in front, so its requests are ignored —
/// silently, with no error. Apple has acknowledged this (FB21087054) and has not
/// fixed it.
///
/// The old Carbon call `SetFrontProcessWithOptions` still works, still restores
/// *all* of an app's things (which the modern replacement has failed to do since
/// macOS 10.15, per Apple's own engineers, FB11974786), and is deprecated rather
/// than private — no SIP disabling, no boot flags, nothing that breaks on the
/// next macOS. So that is the primary path, with the modern call as a fallback.
enum WindowRescue {

    // MARK: - Permission

    /// True when the person has given us permission to move other apps' things.
    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// Asks for permission, showing the system's own prompt.
    static func requestPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    // MARK: - Bringing an app to the front

    /// Puts an app in front of everything, including all of its things.
    /// Returns true if we believe it worked.
    @discardableResult
    static func bringToFront(pid: pid_t) -> Bool {
        // Primary: the deprecated Carbon path, reached through a small C shim
        // because Swift refuses to import pre-10.9 symbols. Restores every
        // window, and works from a background app where the modern call
        // silently does nothing. See LegacyActivation.h for the full reasoning.
        if us_bring_app_to_front(pid) { return true }

        // Fallback: the modern call. Often silently fails from here, but costs
        // nothing to try and does work in some situations.
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.activate(options: [.activateAllWindows])
        }
        return false
    }

    // MARK: - Moving things back

    /// The accessibility handle for one app.
    private static func axApp(_ pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// Every window of an app that the accessibility layer can currently see.
    /// Note: this only ever returns things on the screenful you are looking at.
    private static func axWindows(_ pid: pid_t) -> [AXUIElement] {
        var value: CFTypeRef?
        // Do not hang forever on an app that has stopped responding. A short
        // timeout turns "frozen" into a fast, detectable failure.
        AXUIElementSetMessagingTimeout(axApp(pid), 1.0)
        let err = AXUIElementCopyAttributeValue(
            axApp(pid), kAXWindowsAttribute as CFString, &value)
        guard err == .success, let wins = value as? [AXUIElement] else { return [] }
        return wins
    }

    private static func frame(of win: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }
        var p = CGPoint.zero
        var s = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &p)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }

    @discardableResult
    private static func move(_ win: AXUIElement, to point: CGPoint) -> Bool {
        var p = point
        guard let v = AXValueCreate(.cgPoint, &p) else { return false }
        return AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, v) == .success
    }

    private static func isMinimized(_ win: AXUIElement) -> Bool {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &v) == .success
        else { return false }
        return (v as? Bool) ?? false
    }

    @discardableResult
    private static func unminimize(_ win: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(
            win, kAXMinimizedAttribute as CFString, false as CFTypeRef) == .success
    }

    /// Places a rectangle fully inside a screen, nudging it in from the edges so
    /// the title bar is always grabbable.
    private static func placeInside(_ size: CGSize, screen: CGRect) -> CGPoint {
        let inset: CGFloat = 40
        let x = screen.midX - size.width / 2
        let y = screen.midY - size.height / 2
        return CGPoint(
            x: min(max(x, screen.minX + inset), max(screen.maxX - size.width - inset, screen.minX + inset)),
            y: min(max(y, screen.minY + inset), max(screen.maxY - size.height - inset, screen.minY + inset))
        )
    }

    // MARK: - The two things this can do

    /// Pulls specific stranded things back onto the screen you are using.
    @discardableResult
    static func rescue(_ stranded: [WindowScan.Stranded]) -> Bool {
        guard hasPermission else { return false }
        var movedAny = false

        for item in stranded {
            // The app has to be frontmost for its things to become visible to
            // the accessibility layer at all.
            bringToFront(pid: item.pid)
            usleep(120_000)

            for win in axWindows(item.pid) {
                if isMinimized(win) { unminimize(win) }
                guard let f = frame(of: win) else { continue }
                let screens = NSScreen.screens.map { $0.frame }
                guard !screens.contains(where: { $0.intersects(f) }) else { continue }
                if move(win, to: placeInside(f.size, screen: item.rescueTarget)) {
                    movedAny = true
                }
            }
        }
        return movedAny
    }

    /// The hotkey action: gather everything belonging to the app you are trying
    /// to use onto the screen you are looking at, and put it in front.
    ///
    /// Unminimizes, unhides, and drags anything off the edge back into view.
    @discardableResult
    static func gatherFrontmostApp() -> Bool {
        guard hasPermission else { return false }

        // Which app did the person actually want?
        //
        // NOT whatever is frontmost right now. By the time the key press
        // arrives, macOS has often made *us* frontmost, so asking for the
        // frontmost app rescues unstray itself and nothing happens. And the app
        // they are reaching for frequently has no visible window at all — which
        // is the whole reason they pressed the key — so it may not be frontmost
        // either.
        //
        // ActivityWatch remembers the last real app they switched to, ignoring
        // ourselves. That is the app they are fighting with.
        let target = ActivityWatch.shared.lastUsedApp
            ?? NSWorkspace.shared.frontmostApplication?.processIdentifier

        guard let pid = target, pid != getpid() else { return false }
        return gather(pid: pid)
    }

    @discardableResult
    static func gather(pid: pid_t) -> Bool {
        guard hasPermission else { return false }

        if let app = NSRunningApplication(processIdentifier: pid), app.isHidden {
            app.unhide()
        }
        bringToFront(pid: pid)
        usleep(120_000)

        let target = WindowScan.screenUnderCursor().visibleFrame
        let screens = NSScreen.screens.map { $0.frame }
        var didSomething = false

        for win in axWindows(pid) {
            if isMinimized(win) {
                unminimize(win)
                didSomething = true
            }
            guard let f = frame(of: win) else { continue }
            // Only move what is actually unreachable. Dragging things a person
            // deliberately placed would be its own kind of broken.
            if !screens.contains(where: { $0.intersects(f) }) {
                if move(win, to: placeInside(f.size, screen: target)) { didSomething = true }
            }
        }
        return didSomething
    }
}
