import Cocoa
import ApplicationServices

/// A frontmost app can own a window inside the display yet have that window
/// completely hidden by another app's window. Geometry alone misses this.
///
/// Core Graphics returns on-screen windows from front to back. This uses only
/// process IDs, layers, alpha, and bounds; it never reads titles or pixels.
enum WindowOcclusion {
    struct Window {
        let pid: pid_t
        let layer: Int
        let alpha: CGFloat
        let frame: CGRect
        let ownerName: String

        init(pid: pid_t, layer: Int, alpha: CGFloat, frame: CGRect,
             ownerName: String = "") {
            self.pid = pid
            self.layer = layer
            self.alpha = alpha
            self.frame = frame
            self.ownerName = ownerName
        }
    }

    private static func isCaptureInterface(_ window: Window) -> Bool {
        // The interactive macOS snip shield is a full-screen window with alpha
        // 1 at layer 1498. It deliberately takes input while the app underneath
        // stays frontmost. Its rectangle must not trigger a window repair.
        window.layer > Int(CGWindowLevelForKey(.statusWindow)) &&
            (window.ownerName == "screencapture" ||
             window.ownerName == "Screenshot")
    }

    private static func targets(pid: pid_t, in windows: [Window],
                                screens: [CGRect]) -> [(offset: Int, element: Window)] {
        windows.enumerated().filter { _, window in
            window.pid == pid && window.layer == 0 &&
            WindowUse.isSomethingYouWereWorkingIn(window.frame,
                                                   scope: .oneChosenApp) &&
            !ScreenSpace.visiblePart(of: window.frame, screens: screens).isNull
        }
    }

    /// A conservative answer: every substantial window of the chosen app must
    /// be at least 95% covered by one opaque window from another process.
    /// A partial overlap is normal and must never rearrange a person's desk.
    static func coveredWindow(pid: pid_t, in frontToBack: [Window],
                              screens: [CGRect]) -> CGRect? {
        // A capture session temporarily covers the entire desktop. Wait for it
        // to end before judging any app, including windows behind other panels.
        guard !frontToBack.contains(where: isCaptureInterface) else { return nil }
        let targets = targets(pid: pid, in: frontToBack, screens: screens)
        guard !targets.isEmpty else { return nil }

        // A dialog or palette belonging to the app is itself something the
        // person can see, even if its ordinary windows sit behind other apps.
        if frontToBack.contains(where: { window in
            window.pid == pid && window.layer > 0 &&
            WindowUse.isSomethingYouWereWorkingIn(window.frame,
                                                   scope: .oneChosenApp)
        }) { return nil }

        for (index, target) in targets {
            let visible = ScreenSpace.visiblePart(of: target.frame, screens: screens)
            let area = visible.width * visible.height
            guard area > 0 else { return nil }
            let covered = frontToBack[..<index].contains { other in
                guard other.pid != pid, other.layer >= 0,
                      other.alpha >= 0.95 else { return false }
                let overlap = visible.intersection(other.frame)
                return !overlap.isNull && !overlap.isEmpty &&
                       overlap.width * overlap.height >= area * 0.95
            }
            if !covered { return nil }
        }
        return targets[0].element.frame
    }

    /// Window bounds and fade alpha cannot prove that an app is invisible.
    /// A transparent overlay can occupy the whole rectangle. If the system's
    /// topmost accessibility element at any interior point belongs to the app,
    /// the person can still reach it, so do not move it or warn.
    static func confirmedCoveredWindow(pid: pid_t, in frontToBack: [Window],
                                       screens: [CGRect],
                                       appAtPoint: (CGPoint) -> Bool?) -> CGRect? {
        guard let candidate = coveredWindow(pid: pid, in: frontToBack,
                                            screens: screens) else { return nil }
        let visibleParts = targets(pid: pid, in: frontToBack, screens: screens)
            .map { ScreenSpace.visiblePart(of: $0.element.frame, screens: screens) }
            .sorted { $0.width * $0.height > $1.width * $1.height }
        func hit(_ point: CGPoint) -> Bool? {
            guard screens.contains(where: { $0.contains(point) }) else { return nil }
            return appAtPoint(point)
        }
        // Bound the number of Accessibility messages for apps with many windows.
        for visible in visibleParts.prefix(4) {
            guard hit(CGPoint(x: visible.midX, y: visible.midY)) == false
            else { return nil }
        }
        if let largest = visibleParts.first {
            for x in [CGFloat(0.25), 0.75] {
                for y in [CGFloat(0.25), 0.75] {
                    let point = CGPoint(x: largest.minX + largest.width * x,
                                        y: largest.minY + largest.height * y)
                    guard hit(point) == false else { return nil }
                }
            }
        }
        return candidate
    }

    static func coveredWindow(pid: pid_t) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        let windows: [Window] = list.compactMap { item in
            guard let owner = item[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = item[kCGWindowLayer as String] as? Int,
                  let bounds = item[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], let height = bounds["Height"]
            else { return nil }
            let alpha = (item[kCGWindowAlpha as String] as? CGFloat) ?? 1
            return Window(pid: owner, layer: layer, alpha: alpha,
                          frame: CGRect(x: x, y: y, width: width, height: height),
                          ownerName: item[kCGWindowOwnerName as String] as? String ?? "")
        }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.2)
        return confirmedCoveredWindow(pid: pid, in: windows,
                                      screens: ScreenSpace.screens()) { point in
            var element: AXUIElement?
            guard AXUIElementCopyElementAtPosition(system, Float(point.x),
                                                   Float(point.y), &element) == .success,
                  let element else { return nil }
            var hitPID: pid_t = 0
            guard AXUIElementGetPid(element, &hitPID) == .success else { return nil }
            return hitPID == pid
        }
    }
}
