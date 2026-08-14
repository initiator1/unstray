import Cocoa

/// Keeps other apps' windows and macOS screens in one coordinate system.
///
/// AppKit measures upward from the primary screen's bottom-left corner. The
/// window server and accessibility layer measure downward from its top-left
/// corner. Those systems look identical on one screen and disagree as soon as a
/// screen sits above or below the primary one, so every conversion belongs here.
enum ScreenSpace {

    /// Converts between AppKit coordinates and the window coordinates that
    /// CGWindowList and the accessibility layer both use. Reflecting the same
    /// rectangle twice restores it, so one operation serves both directions.
    static func flip(_ r: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: primaryTop - r.maxY,
               width: r.width, height: r.height)
    }

    /// Every screen, expressed beside CGWindowList and accessibility rectangles.
    static func screens(_ screens: [NSScreen] = NSScreen.screens) -> [CGRect] {
        guard let primary = screens.first else { return [] }
        return screens.map { flip($0.frame, primaryTop: primary.frame.maxY) }
    }

    /// The places where another app's window can sit without the menu bar or
    /// bottom bar covering it, expressed in window coordinates.
    static func usableScreens(_ screens: [NSScreen] = NSScreen.screens) -> [CGRect] {
        guard let primary = screens.first else { return [] }
        return screens.map { flip($0.visibleFrame, primaryTop: primary.frame.maxY) }
    }

    /// The bounding box of every piece a window shares with the current screens.
    /// A window spanning two screens remains one reachable shape instead of two
    /// unrelated fragments.
    ///
    /// Screens set beside each other share an edge however far up or down one is
    /// slid, so the pieces of a window touching both always meet, and the
    /// bounding box is the shape the person sees.
    ///
    /// Two screens dragged to meet only at a CORNER are the exception: the
    /// pieces are then separated by dead space, and this counts that space as
    /// visible. Left that way on purpose, 2026-08-14. Every caller uses this
    /// number to decide whether to speak — the size floor in `WindowUse.judge`,
    /// the "this app still has something on screen" test in `findOutOfReach`,
    /// and one line of the log — so a generous answer keeps unstray quiet, while
    /// a stingy one invents problems. Crying wolf is the failure this app has
    /// actually shipped; missing a two-corner window on a diagonal desk is not.
    static func visiblePart(of window: CGRect, screens: [CGRect]) -> CGRect {
        screens.reduce(CGRect.null) { visible, screen in
            let part = window.intersection(screen)
            guard !part.isNull, !part.isEmpty else { return visible }
            return visible.union(part)
        }
    }

    /// Moves only the dimensions that cross a usable edge. The screen holding
    /// most of the window preserves the person's placement; the preferred screen
    /// is used only when the window has no current home.
    static func slideIntoView(_ window: CGRect, screens: [CGRect],
                              preferred: CGRect) -> CGPoint {
        let held = screens.map { screen -> (CGRect, CGFloat) in
            let part = window.intersection(screen)
            let area = part.isNull || part.isEmpty ? 0 : part.width * part.height
            return (screen, area)
        }
        let best = held.max { $0.1 < $1.1 }
        let target: CGRect
        if let best, best.1 > 0 {
            target = best.0
        } else if !preferred.isNull, !preferred.isEmpty {
            target = preferred
        } else if let first = screens.first {
            target = first
        } else {
            return window.origin
        }

        let x: CGFloat
        if window.width > target.width {
            x = target.minX
        } else {
            x = min(max(window.minX, target.minX), target.maxX - window.width)
        }

        let y: CGFloat
        if window.height > target.height {
            y = target.minY
        } else {
            y = min(max(window.minY, target.minY), target.maxY - window.height)
        }
        return CGPoint(x: x, y: y)
    }
}
