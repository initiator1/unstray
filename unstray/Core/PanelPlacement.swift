import Cocoa

/// Where the panel is allowed to sit.
///
/// This is separate from the app, and pure, because getting it wrong is not
/// obvious from reading the code — it is only obvious when a panel is hanging off
/// the side of a monitor with its text cut in half. Twice now. So the arithmetic
/// lives here where tests can hold it still.
///
/// The case that keeps biting: three monitors side by side do not form one big
/// rectangle. On a desk with a tall monitor on the left and a shorter built-in
/// display beside it, the space above the built-in is not part of any screen.
/// A panel near the left monitor's top-right corner spills into that gap and gets
/// cut off, even though something is "next to" it.
enum PanelPlacement {

    /// Space kept between the panel and the edge of the screen.
    static let margin: CGFloat = 8

    /// Moves a panel so it sits entirely within `visible`.
    ///
    /// If the panel is larger than the screen in either direction it is pinned to
    /// the top-left of that axis, because showing the beginning of something too
    /// big beats showing the middle of it.
    static func clamp(_ panel: CGRect, into visible: CGRect) -> CGRect {
        var r = panel

        if r.width >= visible.width - margin * 2 {
            r.origin.x = visible.minX + margin
        } else {
            if r.maxX > visible.maxX - margin { r.origin.x = visible.maxX - r.width - margin }
            if r.minX < visible.minX + margin { r.origin.x = visible.minX + margin }
        }

        if r.height >= visible.height - margin * 2 {
            // Pin to the top: the headline matters more than the buttons.
            r.origin.y = visible.maxY - r.height - margin
        } else {
            if r.maxY > visible.maxY - margin { r.origin.y = visible.maxY - r.height - margin }
            if r.minY < visible.minY + margin { r.origin.y = visible.minY + margin }
        }
        return r
    }

    /// Which screen a panel belongs to.
    ///
    /// Deliberately not `NSWindow.screen`: that reports whichever screen holds the
    /// largest part of the window, which is the wrong answer exactly when the
    /// window is hanging off an edge — the moment this matters.
    ///
    /// Preference order:
    ///   1. the screen holding the menu-bar icon it came from
    ///   2. the screen holding the panel's own top-left corner
    ///   3. whichever screen it overlaps most
    ///   4. the main screen
    static func screen(forAnchor anchor: CGPoint?,
                       panel: CGRect,
                       screens: [NSScreen]) -> NSScreen? {
        if let a = anchor, let s = screens.first(where: { $0.frame.contains(a) }) {
            return s
        }
        let topLeft = CGPoint(x: panel.minX, y: panel.maxY - 1)
        if let s = screens.first(where: { $0.frame.contains(topLeft) }) {
            return s
        }
        let overlapping = screens
            .map { ($0, $0.frame.intersection(panel)) }
            .filter { !$1.isNull && !$1.isEmpty }
            .max { a, b in (a.1.width * a.1.height) < (b.1.width * b.1.height) }
        return overlapping?.0 ?? NSScreen.main
    }
}
