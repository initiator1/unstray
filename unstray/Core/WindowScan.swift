import Cocoa

/// Finds things that are open but sitting where no screen can reach them.
///
/// This happens when you unplug a screen. Your Mac leaves things sitting at the
/// spot where that screen used to be — off the edge of everything you own. The
/// thing is still open. It is just parked somewhere you cannot look.
///
/// Two different lists have to be cross-referenced to see this, and neither one
/// is enough on its own:
///   - CGWindowList sees everything, on every screenful, but cannot move anything.
///   - The accessibility list can move things, but only sees the screenful you
///     are currently looking at.
/// We match them up by position and size, since there is no shared identifier.
enum WindowScan {

    /// The message for whatever we could not fix. One place, so every one of
    /// these passes the same read-aloud test.
    static func unusable(appName: String, problem: Usability.Problem) -> Finding {
        unusable(appName: appName, kind: problem.kind)
    }

    /// Message selection needs no live window, so handles stay inside Usability
    /// and cannot outlive the window they describe.
    static func unusable(appName: String,
                         kind: Usability.Problem.Kind) -> Finding {
        switch kind {
        case .notResponding:  return appNotResponding(appName: appName)
        case .hidden,
             .nothingToShow:  return appShowsNothing(appName: appName)
        case .titleBarOutOfReach: return titleBarOutOfReach(appName: appName)
        case .pushedOffTheEdge: return windowOffTheEdge(appName: appName)
        }
    }

    /// The app has stopped answering. Nothing outside it can fix that, so this
    /// exists purely so nobody is left clicking a dead picture in the bar.
    static func appNotResponding(appName: String) -> Finding {
        Finding(
            id: "not-responding",
            kind: .appNotResponding,
            severity: .nowBroken,
            headline: "\(appName) has stopped answering.",
            explanation: """
            Clicking again will not wake it up. \(appName) is still running, it \
            has just stopped listening, so nothing you click reaches it.

            It usually recovers on its own within a minute. If it does not, you \
            can force it to quit and reopen it, though you may lose anything you \
            had not saved.
            """,
            actionLabel: "Show me how to force it to quit",
            costWarning: nil,
            technicalNote: "AX request timed out (kAXErrorCannotComplete) at 0.5s while app was frontmost.",
            repair: {
                // Opens the panel where a person can force-quit safely, rather
                // than doing it for them and losing their unsaved work.
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                return true
            }
        )
    }

    /// The window is on screen but its top edge is not, so it cannot be dragged.
    static func titleBarOutOfReach(appName: String) -> Finding {
        Finding(
            id: "title-bar-out-of-reach",
            kind: .titleBarOutOfReach,
            severity: .nowBroken,
            headline: "You can see \(appName), but you cannot move it.",
            explanation: """
            You move a window by dragging its top edge. \(appName)'s top edge is \
            above your screen, so there is nothing left to grab.

            This usually happens after a screen is unplugged, or when your Mac \
            rearranges things on its own.

            I can slide it down until you can reach it again.
            """,
            actionLabel: "Slide it back down",
            costWarning: nil,
            technicalNote: "Window intersects a screen but its top 30pt strip does not; no grabbable title bar.",
            repair: {
                guard let app = NSWorkspace.shared.runningApplications.first(where: {
                    $0.localizedName == appName
                }) else { return false }
                guard case .titleBarOutOfReach(let w, let f)? =
                        Usability.problem(for: app) else { return false }
                return Usability.bringTitleBarIntoReach(w, frame: f)
            }
        )
    }

    /// Built when you switched to an app, nothing appeared, and asking the app
    /// to open a window did not work either. Apple's FB21087054.
    static func appShowsNothing(appName: String) -> Finding {
        Finding(
            id: "shows-nothing",
            kind: .appShowsNothing,
            severity: .nowBroken,
            headline: "You clicked \(appName) and nothing came up.",
            explanation: """
            This is a bug in macOS, and clicking more times will not help.

            \(appName) really is open. Your Mac just never gave it a window to \
            show you, and did not notice.

            I asked it to open one and it did not answer. Quitting \(appName) and \
            opening it again usually sorts it out.
            """,
            actionLabel: "Try again for me",
            costWarning: nil,
            technicalNote: "FB21087054: app frontmost, activationPolicy .regular, no window >=120pt tall on any screen; kAEReopenApplication sent, still nothing.",
            repair: { AppReopen.askByName(appName) }
        )
    }

    struct OutOfReach {
        enum Reason: Equatable {
            case strandedOffEveryScreen
            case pushedPastTheEdge
        }

        let appName: String
        let pid: pid_t
        let frame: CGRect
        let reason: Reason
        /// Where it should go: the screen the mouse is on, in window coordinates.
        var rescueTarget: CGRect
    }

    /// Apps that live in the bar at the top and never have real things of their
    /// own. Counting these produces false alarms — an earlier version of this
    /// scan reported eight "problems" that were all menu-bar helpers.
    private static func isBackgroundHelper(_ app: NSRunningApplication) -> Bool {
        // Two ways to be a thing with no windows of its own: live in the top bar,
        // or be started with an instruction never to open one. The second kind
        // still has a Dock icon and still takes the menu bar, so it has to be
        // named separately. See WindowlessByDesign.
        app.activationPolicy != .regular || WindowlessByDesign.applies(to: app)
    }

    /// The screen the mouse is on — where a person is currently looking, and so
    /// the only sensible place to put something back.
    static func screenUnderCursor() -> CGRect {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return .null }
        let mouse = NSEvent.mouseLocation
        let target = screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? primary
        return ScreenSpace.flip(target.visibleFrame,
                                primaryTop: primary.frame.maxY)
    }

    /// Every real window that is lost or leaves too little on screen to use.
    /// One window-server list supplies both answers, so their filters cannot
    /// drift into separate systems.
    static func findOutOfReach() -> [OutOfReach] {
        let screens = ScreenSpace.screens()
        guard !screens.isEmpty,
              let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
                  as? [[String: Any]]
        else { return [] }

        // pid -> app, so we can drop menu-bar helpers.
        var appsByPid: [pid_t: NSRunningApplication] = [:]
        for a in NSWorkspace.shared.runningApplications {
            appsByPid[a.processIdentifier] = a
        }

        let target = screenUnderCursor()
        var classified: [(appName: String, pid: pid_t, frame: CGRect,
                          reason: OutOfReach.Reason?)] = []
        var pidsWithVisibleWindows: Set<pid_t> = []

        for w in list {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  let pidNum = w[kCGWindowOwnerPID as String] as? pid_t,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = b["Width"], let height = b["Height"],
                  let x = b["X"], let y = b["Y"]
            else { continue }

            guard let app = appsByPid[pidNum], !isBackgroundHelper(app) else { continue }

            let frame = CGRect(x: x, y: y, width: width, height: height)
            // Whether this window belongs to the screenful the person is looking
            // at right now. Measured: a window shoved off the right edge of the
            // current screenful still reports true; every window belonging to
            // another screenful reports false, even one sitting squarely in the
            // middle of the screen.
            let onThisScreenful = (w[kCGWindowIsOnscreen as String] as? Bool) ?? false
            // The chosen-app floor decides whether this process has a visible
            // window. A shorter window still proves the app has something on
            // screen, even when the machine-wide sweep will not report it.
            let report = WindowUse.judge(frame,
                                         onThisScreenful: onThisScreenful,
                                         screens: screens,
                                         scope: .oneChosenApp)
            guard report.verdict != .notSomethingYouWereWorkingIn else { continue }
            if !report.visible.isNull { pidsWithVisibleWindows.insert(pidNum) }

            // A machine-wide sweep has no signal that the person chose this app,
            // so it keeps the higher historical bar that prevents false alarms.
            guard WindowUse.isSomethingYouWereWorkingIn(
                frame, scope: .everyWindow
            ) else { continue }

            let reason: OutOfReach.Reason?
            switch report.verdict {
            case .lostOffEveryScreen:
                reason = .strandedOffEveryScreen

            case .pushedPastTheEdge:
                // Only ever report an edge-pushed window we can actually move.
                //
                // The accessibility layer reaches only the current screenful,
                // and there is no public way to move a window between them. A
                // window one screenful over is not hurting anyone right now —
                // nobody is looking at it — and reporting it would put a "Slide
                // it back" button on screen that does nothing, forever. That is
                // the exact failure this app exists to remove. When the person
                // moves to that screenful, this scan sees it and can fix it.
                reason = report.canBeMoved ? .pushedPastTheEdge : nil

            case .usable,
                 .notSomethingYouWereWorkingIn,
                 .titleBarOutOfReach:
                reason = nil
            }
            classified.append((app.localizedName ?? "Something", pidNum, frame,
                               reason))
        }

        // A fully stranded second window does not make a visible app look lost.
        // An off-edge window remains broken even when the same app has another
        // useful window, which is the measured Epson case.
        return classified.compactMap { item in
            guard let reason = item.reason else { return nil }
            if reason == .strandedOffEveryScreen,
               pidsWithVisibleWindows.contains(item.pid) { return nil }
            return OutOfReach(appName: item.appName, pid: item.pid,
                              frame: item.frame, reason: reason,
                              rescueTarget: target)
        }
    }

    /// Builds the "things are parked off the edge" finding, if there are any.
    static func check() -> Finding? {
        let stranded = findOutOfReach().filter {
            $0.reason == .strandedOffEveryScreen
        }
        guard !stranded.isEmpty else { return nil }

        // Name the actual apps. "Your Notes and your Chrome" beats "3 windows"
        // for someone who does not know the word "window".
        let names = Array(Set(stranded.map { $0.appName })).sorted()
        // No "your" — plenty of apps have proper names, and "Your Claude" reads
        // like a typo. Naming the app plainly works for every case.
        let subject: String
        switch names.count {
        case 1:  subject = "\(names[0]) is"
        case 2:  subject = "\(names[0]) and \(names[1]) are"
        default: subject = "\(names[0]), \(names[1]), and \(names.count - 2) other app\(names.count - 2 == 1 ? "" : "s") are"
        }

        return Finding(
            id: "stranded-windows",
            kind: .strandedWindows,
            severity: .nowBroken,
            headline: "\(subject) open, but you cannot see \(names.count == 1 ? "it" : "them").",
            explanation: """
            You had another screen plugged in at some point. When it went away, \
            your Mac left \(names.count == 1 ? "this window" : "these windows") \
            sitting where that screen used to be, past the edge of everything you \
            have now.

            Nothing is lost — \(names.count == 1 ? "it is" : "they are") still \
            open, just parked somewhere you cannot look.

            I can bring \(names.count == 1 ? "it" : "them") back to the screen \
            you are using.
            """,
            actionLabel: names.count == 1 ? "Bring it back" : "Bring them back",
            costWarning: nil,
            technicalNote: "Stranded windows: " + stranded.map {
                "\($0.appName)@(\(Int($0.frame.minX)),\(Int($0.frame.minY)))"
            }.joined(separator: ", "),
            repair: {
                WindowRescue.rescue(stranded)
            }
        )
    }

    /// Builds the shared single-app explanation used by the general scan and
    /// the quiet app-activation repair when it cannot complete the move.
    static func windowOffTheEdge(appName: String) -> Finding {
        offEdgeFinding(names: [appName], items: findOutOfReach().filter {
            $0.reason == .pushedPastTheEdge && $0.appName == appName
        })
    }

    /// Reports windows whose remaining on-screen piece is too small to use.
    static func checkOffTheEdge() -> Finding? {
        let items = findOutOfReach().filter { $0.reason == .pushedPastTheEdge }
        guard !items.isEmpty else { return nil }
        // Built here rather than handed to `windowOffTheEdge`, which would walk
        // the whole window list a second time and could come back with a
        // different answer than the one this finding was written from.
        return offEdgeFinding(names: Array(Set(items.map { $0.appName })).sorted(),
                              items: items)
    }

    /// Keeps every off-edge finding on the same words and the same repair path.
    private static func offEdgeFinding(names: [String],
                                       items: [OutOfReach]) -> Finding {
        let headline: String
        switch names.count {
        case 1:
            headline = "One of \(names[0])'s windows is hanging off the edge of your screen."
        case 2:
            headline = "\(names[0]) and \(names[1]) each have a window hanging off the edge of your screen."
        default:
            let n = names.count - 2
            headline = "\(names[0]), \(names[1]), and \(n) other app\(n == 1 ? "" : "s") each have a window hanging off the edge of your screen."
        }

        // Each window has its own sliver, so the plural is "each", not "them".
        // "Only a sliver of them is still on your screen" reads as one shared
        // sliver, and does not agree with its own verb.
        let one = names.count == 1
        let sliverOf = one ? "it" : "each"
        let them = one ? "it" : "them"
        let screens = ScreenSpace.screens()
        return Finding(
            id: "window-off-the-edge",
            kind: .windowOffTheEdge,
            severity: .nowBroken,
            headline: headline,
            explanation: """
            Nothing is lost. Only a sliver of \(sliverOf) is still on your screen, so there is almost nothing left to read and almost nothing left to click.

            This happens when a screen is unplugged, or when your Mac puts a window back where it used to be instead of where you are looking.

            I can slide \(them) back until you can see all of \(them).
            """,
            actionLabel: names.count == 1 ? "Slide it back" : "Slide them back",
            costWarning: nil,
            technicalNote: "Off-edge windows: " + items.map { item in
                let visible = ScreenSpace.visiblePart(of: item.frame, screens: screens)
                return "\(item.appName)@(\(Int(item.frame.minX)),\(Int(item.frame.minY))) "
                    + "\(Int(item.frame.width))x\(Int(item.frame.height)) visible "
                    + "\(Int(visible.width))x\(Int(visible.height))"
            }.joined(separator: ", "),
            repair: {
                if !items.isEmpty, WindowRescue.rescue(items) { return true }

                // The check that runs when a person selects an app accepts a
                // shorter window than this all-Spaces scan does, so it can raise
                // this finding about a window the scan will not hand back. The
                // button must still do what it says, so ask the same question
                // that raised the finding and move whatever it points at.
                var moved = false
                for name in names {
                    guard let app = NSWorkspace.shared.runningApplications.first(where: {
                              $0.localizedName == name
                          }),
                          case .pushedOffTheEdge(let w, let f)? = Usability.problem(for: app)
                    else { continue }
                    if Usability.slideFullyIntoView(w, frame: f) { moved = true }
                }
                return moved
            }
        )
    }
}
