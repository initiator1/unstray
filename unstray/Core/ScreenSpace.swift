import Cocoa

/// Keeps other apps' windows and macOS screens in one coordinate system.
///
/// AppKit measures upward from the primary screen's bottom-left corner. The
/// window server and accessibility layer measure downward from its top-left
/// corner. Those systems look identical on one screen and disagree as soon as a
/// screen sits above or below the primary one, so every comparison belongs here.
enum ScreenSpace {

    /// These floors define whether the visible part can still serve as a real
    /// window. Keeping them here prevents scanning and repair from drifting into
    /// different answers about the same rectangle.
    static let smallestRealWindowWidth: CGFloat = 200
    static let smallestRealWindowHeight: CGFloat = 120

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
    static func visiblePart(of window: CGRect, screens: [CGRect]) -> CGRect {
        screens.reduce(CGRect.null) { visible, screen in
            let part = window.intersection(screen)
            guard !part.isNull, !part.isEmpty else { return visible }
            return visible.union(part)
        }
    }

    /// A visible sliver is not useful. The part left on the screens must still
    /// be large enough to count as the kind of window the app scans for.
    static func isReachable(_ window: CGRect, screens: [CGRect]) -> Bool {
        let visible = visiblePart(of: window, screens: screens)
        return !visible.isNull
            && visible.width >= smallestRealWindowWidth
            && visible.height >= smallestRealWindowHeight
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
