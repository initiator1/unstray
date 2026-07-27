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
        switch problem {
        case .notResponding:  return appNotResponding(appName: appName)
        case .hidden,
             .nothingToShow:  return appShowsNothing(appName: appName)
        case .titleBarOutOfReach: return titleBarOutOfReach(appName: appName)
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
            You did not break it, and clicking again will not wake it up.

            \(appName) is still running, but it has stopped listening to your Mac, \
            so nothing you click reaches it. This happens to every app sometimes.

            Most of the time it recovers on its own after a minute. If it does \
            not, you can force it to quit and open it again — you may lose \
            anything you had not saved.
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
            The strip along the top of a thing is what you drag to move it. \
            \(appName)'s strip is above the top of your screen, so there is \
            nothing left to grab.

            That is not your fault. It usually happens after a screen is \
            unplugged, or after your Mac has rearranged things on its own.

            I can slide it down so you can reach the top of it again.
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
            This is a bug in macOS itself, not something you did. Clicking more \
            times will not help.

            \(appName) really is open — your Mac just did not give it anything to \
            show you, and did not notice.

            I asked it to open something for you and it did not answer. Opening \
            \(appName) again usually works the second time.
            """,
            actionLabel: "Try again for me",
            costWarning: nil,
            technicalNote: "FB21087054: app frontmost, activationPolicy .regular, no window >=120pt tall on any screen; kAEReopenApplication sent, still nothing.",
            repair: { AppReopen.askByName(appName) }
        )
    }

    struct Stranded {
        let appName: String
        let pid: pid_t
        let frame: CGRect
        /// Where it should go: the screen the mouse is on.
        var rescueTarget: CGRect
    }

    /// Apps that live in the bar at the top and never have real things of their
    /// own. Counting these produces false alarms — an earlier version of this
    /// scan reported eight "problems" that were all menu-bar helpers.
    private static func isBackgroundHelper(_ app: NSRunningApplication) -> Bool {
        app.activationPolicy != .regular
    }

    /// True when this rectangle touches none of the screens you actually have.
    private static func isUnreachable(_ r: CGRect, screens: [CGRect]) -> Bool {
        !screens.contains { $0.intersects(r) }
    }

    /// The screen the mouse is on — where a person is currently looking, and so
    /// the only sensible place to put something back.
    static func screenUnderCursor() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// Everything open right now that no screen can reach.
    static func findStranded() -> [Stranded] {
        let screens = NSScreen.screens.map { $0.frame }
        guard !screens.isEmpty,
              let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
                  as? [[String: Any]]
        else { return [] }

        // pid -> app, so we can drop menu-bar helpers.
        var appsByPid: [pid_t: NSRunningApplication] = [:]
        for a in NSWorkspace.shared.runningApplications {
            appsByPid[a.processIdentifier] = a
        }

        let target = screenUnderCursor().visibleFrame
        var out: [Stranded] = []

        for w in list {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  let pidNum = w[kCGWindowOwnerPID as String] as? pid_t,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = b["Width"], let height = b["Height"],
                  let x = b["X"], let y = b["Y"]
            else { continue }

            // Toolbars, shadows, and tiny helper surfaces are not "things you
            // were working in". Real windows are bigger than this.
            guard width >= 200, height >= 150 else { continue }

            guard let app = appsByPid[pidNum], !isBackgroundHelper(app) else { continue }

            let frame = CGRect(x: x, y: y, width: width, height: height)
            guard isUnreachable(frame, screens: screens) else { continue }

            out.append(Stranded(
                appName: app.localizedName ?? "Something",
                pid: pidNum,
                frame: frame,
                rescueTarget: target
            ))
        }
        return out
    }

    /// Builds the "things are parked off the edge" finding, if there are any.
    static func check() -> Finding? {
        let stranded = findStranded()
        guard !stranded.isEmpty else { return nil }

        // Name the actual apps. "Your Notes and your Chrome" beats "3 windows"
        // for someone who does not know the word "window".
        let names = Array(Set(stranded.map { $0.appName })).sorted()
        let subject: String
        switch names.count {
        case 1:  subject = "Your \(names[0]) is"
        case 2:  subject = "Your \(names[0]) and your \(names[1]) are"
        default: subject = "Your \(names[0]), your \(names[1]), and \(names.count - 2) other thing\(names.count - 2 == 1 ? "" : "s") are"
        }

        return Finding(
            id: "stranded-windows",
            kind: .strandedWindows,
            severity: .nowBroken,
            headline: "\(subject) open, but you cannot see \(names.count == 1 ? "it" : "them").",
            explanation: """
            You had another screen plugged in at some point. When it was \
            unplugged, your Mac left \(names.count == 1 ? "this" : "these") sitting \
            where that screen used to be — past the edge of every screen you have now.

            Nothing was lost. \(names.count == 1 ? "It is" : "They are") still open. \
            \(names.count == 1 ? "It is" : "They are") just parked somewhere you cannot look.

            I can pull \(names.count == 1 ? "it" : "them") back to the screen you are using.
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
}
