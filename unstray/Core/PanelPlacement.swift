import Cocoa

/// Where the panel is allowed to sit.
///
/// This is separate from the app, and pure, because getting it wrong is not
/// obvious from reading the code — it is only obvious when a panel is hanging off
/// the side of a monitor with its text cut in half. Three times now. So the
/// arithmetic lives here where tests can hold it still.
///
/// Two things go wrong, and they are not the same thing.
///
/// **The screen is not one big rectangle.** Three monitors side by side do not
/// form one. A tall monitor next to a shorter built-in display leaves dead space
/// above the shorter one, and a panel near the tall monitor's top-right corner
/// spills into that gap — cut off, even though another screen is "next to" it.
///
/// **The menu-bar icon is not always on a screen.** A menu-bar manager, or macOS
/// running out of room in the menu bar, hides an icon by parking its window
/// thousands of points off the left edge of everything — measured at x = -10093
/// on this Mac — while the icon still reports itself as visible. Hanging a panel
/// off that point makes AppKit drop it against the left edge of the leftmost
/// monitor, which is how the panel ends up on a screen the person is not even
/// looking at. Every number here is worthless if the anchor is not checked first.
enum PanelPlacement {

    /// Space kept between the visible panel and the edge of the screen.
    static let margin: CGFloat = 8

    /// One display, reduced to the only two rectangles that decide anything.
    ///
    /// Plain rectangles rather than `NSScreen`, so a three-monitor desk can be
    /// written down in a test on a laptop with nothing plugged in.
    struct Display: Equatable {
        /// Everything, menu bar included.
        let frame: CGRect
        /// What a panel may actually use: menu bar and Dock already taken off.
        /// These insets differ per display, so this is never `frame`.
        let visible: CGRect

        init(frame: CGRect, visible: CGRect) {
            self.frame = frame
            self.visible = visible
        }
    }

    // MARK: - Is the menu-bar icon somewhere we can hang a panel from?

    /// True only when the icon is genuinely on one of the screens.
    ///
    /// Rejects the two states measured on this Mac, both of which look fine to
    /// code that does not check:
    ///   - hidden by a menu-bar manager: `(-10093, 729, 28, 26)` — on no display
    ///   - not laid out yet: `(0, 0, 28, 0)` — zero height, and its corner sits
    ///     inside the primary screen, so a naive `contains` says yes
    static func isUsableAnchor(_ anchor: CGRect?, displays: [Display]) -> Bool {
        guard let a = anchor, a.width > 0, a.height > 0 else { return false }
        let centre = CGPoint(x: a.midX, y: a.midY)
        return displays.contains { $0.frame.contains(centre) }
    }

    // MARK: - Which screen the panel belongs on

    /// Index into `displays`, or nil when there are none.
    ///
    /// Deliberately not `NSWindow.screen`: that reports whichever screen holds
    /// the largest part of the window, which is the wrong answer exactly when
    /// the window is hanging off an edge — the moment this matters.
    ///
    /// Also deliberately not the panel's own position. Two earlier versions
    /// guessed from where the panel had landed, which is circular: the panel's
    /// position is the thing that is wrong. The pointer is not a guess — the
    /// person clicked or pressed a key, so that is the screen they are using.
    ///
    /// Order: the menu-bar icon if it is really on a screen, then the pointer,
    /// then the primary screen.
    static func targetDisplay(anchor: CGRect?,
                              pointer: CGPoint?,
                              displays: [Display]) -> Int? {
        guard !displays.isEmpty else { return nil }

        if isUsableAnchor(anchor, displays: displays), let a = anchor {
            let centre = CGPoint(x: a.midX, y: a.midY)
            if let i = displays.firstIndex(where: { $0.frame.contains(centre) }) { return i }
        }
        if let p = pointer, let i = displays.firstIndex(where: { $0.frame.contains(p) }) {
            return i
        }
        return 0
    }

    // MARK: - Where to hang it when the icon is nowhere

    /// A point just under the menu bar, at the right of the screen the person is
    /// using — where a panel opened from the menu bar belongs.
    ///
    /// Used when the icon is hidden. The panel then appears where it would have
    /// appeared if the icon were visible, instead of wherever AppKit rescues it
    /// to when asked to hang something off a window parked in the void.
    static func fallbackAnchor(on display: Display) -> CGRect {
        CGRect(x: display.visible.maxX - margin - 1,
               y: display.visible.maxY,
               width: 1, height: 1)
    }

    // MARK: - Keeping it on the screen

    /// Moves a panel so the part of it a person can see sits entirely within
    /// `visible`.
    ///
    /// `shadow` is the transparent border the window carries around the panel
    /// itself — 13pt on every side, measured. Clamping the whole window frame
    /// instead pushes the panel 13pt further in than it needs to go, and reports
    /// a panel as spilling when only its shadow is over the line.
    ///
    /// If the panel is larger than the screen in either direction it is pinned to
    /// the top-left of that axis, because showing the beginning of something too
    /// big beats showing the middle of it.
    static func clamp(_ panel: CGRect, into visible: CGRect, shadow: CGFloat = 0) -> CGRect {
        // Room the window frame may occupy so that the visible panel inside it
        // still respects the margin.
        let bounds = visible.insetBy(dx: -shadow, dy: -shadow)
        var r = panel

        if r.width >= bounds.width - margin * 2 {
            r.origin.x = bounds.minX + margin
        } else {
            if r.maxX > bounds.maxX - margin { r.origin.x = bounds.maxX - r.width - margin }
            if r.minX < bounds.minX + margin { r.origin.x = bounds.minX + margin }
        }

        if r.height >= bounds.height - margin * 2 {
            // Pin to the top: the headline matters more than the buttons.
            r.origin.y = bounds.maxY - r.height - margin
        } else {
            if r.maxY > bounds.maxY - margin { r.origin.y = bounds.maxY - r.height - margin }
            if r.minY < bounds.minY + margin { r.origin.y = bounds.minY + margin }
        }
        return r
    }

    /// The part of a panel window a person can actually see, shadow taken off.
    static func visiblePart(of panel: CGRect, shadow: CGFloat) -> CGRect {
        panel.insetBy(dx: shadow, dy: shadow)
    }

    /// Where the panel should end up, start to finish: hung under the menu-bar
    /// icon when that icon is real, under the top-right of the screen the person
    /// is using when it is not, and in both cases fully on that screen.
    ///
    /// The app lets AppKit do the hanging and only applies `clamp`, so that a
    /// panel which already lands correctly is not nudged. This computes the whole
    /// answer in one piece so a test can assert on it without a screen attached.
    static func panelRect(size: CGSize,
                          anchor: CGRect?,
                          pointer: CGPoint?,
                          displays: [Display],
                          shadow: CGFloat = 0) -> CGRect? {
        guard let i = targetDisplay(anchor: anchor, pointer: pointer, displays: displays)
        else { return nil }
        let display = displays[i]

        let hang = isUsableAnchor(anchor, displays: displays)
            ? anchor!
            : fallbackAnchor(on: display)

        // Centred under whatever it hangs from, top edge on the menu-bar line.
        let unclamped = CGRect(x: hang.midX - size.width / 2,
                               y: hang.minY - size.height,
                               width: size.width,
                               height: size.height)
        return clamp(unclamped, into: display.visible, shadow: shadow)
    }
}

// MARK: - The real screens

extension PanelPlacement {
    /// `NSScreen` reduced to the rectangles above. `NSScreen.screens[0]` is the
    /// primary, which is what the fallback in `targetDisplay` means.
    static func displays(_ screens: [NSScreen] = NSScreen.screens) -> [Display] {
        screens.map { Display(frame: $0.frame, visible: $0.visibleFrame) }
    }
}
