import CoreGraphics

/// Decides whether a person can use one window where it is.
///
/// unstray learned this lesson twice. CotEditor left a 26pt strip that existed
/// but was not a window a person could use. Epson left a 40pt sliver touching a
/// screen, which also existed and was also useless. Keeping the whole judgement
/// here stops each caller from raising one bar while leaving the others behind.
enum WindowUse {

    /// How high the bar for "something you were working in" sits, and why it
    /// moves. Confidence comes from context: when the person has just selected
    /// an app they have already told us which app they mean, so a shorter
    /// window still counts. A sweep over every window on the machine has no
    /// such signal, and a false alarm there is about an app they never
    /// mentioned, so it holds a higher bar.
    enum Scope: Equatable {
        case oneChosenApp
        case everyWindow

        var minimumWidth: CGFloat { 200 }

        var minimumHeight: CGFloat {
            switch self {
            case .oneChosenApp: 120
            case .everyWindow: 150
            }
        }
    }

    enum Verdict: Equatable {
        /// A person can read it and click it where it is.
        case usable
        /// A toolbar, a shadow, a leftover strip. Not something you were
        /// working in. CotEditor's leftovers were 26pt tall.
        case notSomethingYouWereWorkingIn
        /// Touches no screen at all. Usually where an unplugged screen used to be.
        case lostOffEveryScreen
        /// Touches a screen, but too little of it is left to read or click.
        case pushedPastTheEdge
        /// Big enough and on a screen, but the strip you drag it by is not.
        case titleBarOutOfReach
    }

    struct Report: Equatable {
        let frame: CGRect
        /// The part a person can actually see. `.null` when it touches nothing.
        /// Always computed, whatever the verdict.
        let visible: CGRect
        /// Whether this window belongs to the screenful in front of the person.
        let onThisScreenful: Bool
        let verdict: Verdict

        /// True when this app can do something about it. The accessibility layer
        /// reaches only the current screenful and there is no public way to move
        /// a window between them, so a window one screenful over can be seen and
        /// never touched.
        var canBeMoved: Bool { onThisScreenful }
    }

    private static let titleBarHeight: CGFloat = 30

    /// The one question this app asks about a window.
    static func judge(_ frame: CGRect,
                      onThisScreenful: Bool,
                      screens: [CGRect],
                      scope: Scope) -> Report {
        let visible = ScreenSpace.visiblePart(of: frame, screens: screens)
        let verdict: Verdict

        if !isSomethingYouWereWorkingIn(frame, scope: scope) {
            verdict = .notSomethingYouWereWorkingIn
        } else if visible.isNull {
            verdict = .lostOffEveryScreen
        // The visible remainder always uses 200x120. Only the earlier filter on
        // the window's own height rises to 150 during a machine-wide sweep.
        } else if visible.width < Scope.oneChosenApp.minimumWidth
                    || visible.height < Scope.oneChosenApp.minimumHeight {
            verdict = .pushedPastTheEdge
        } else if !hasReachableTitleBar(frame, screens: screens) {
            verdict = .titleBarOutOfReach
        } else {
            verdict = .usable
        }

        return Report(frame: frame, visible: visible,
                      onThisScreenful: onThisScreenful, verdict: verdict)
    }

    /// The size bar on its own, for the one caller that needs to apply a
    /// different bar than the one it judged at. See `findOutOfReach`.
    static func isSomethingYouWereWorkingIn(_ frame: CGRect, scope: Scope) -> Bool {
        frame.width >= scope.minimumWidth && frame.height >= scope.minimumHeight
    }

    /// True when the top strip of the window is somewhere the mouse can reach.
    private static func hasReachableTitleBar(_ frame: CGRect,
                                             screens: [CGRect]) -> Bool {
        let bar = CGRect(x: frame.minX, y: frame.minY,
                         width: frame.width, height: titleBarHeight)
        return screens.contains { $0.intersects(bar) }
    }
}
