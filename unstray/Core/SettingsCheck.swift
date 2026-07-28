import Cocoa

/// Reads the three macOS settings that decide whether your Mac can lose things.
///
/// Any of the three can end up wrong, and macOS never mentions it either way.
/// They get changed by hand — often by someone trying to fix the very problem the
/// change then causes — and they can also differ after a major OS upgrade or a
/// migration to a new Mac. Whatever the cause, nothing tells you, and the effects
/// (black screens, windows you cannot reach) look nothing like a settings problem.
enum SettingsCheck {

    // MARK: - Reading

    private static func readBool(domain: String, key: String) -> Bool? {
        let d: UserDefaults?
        if domain == "NSGlobalDomain" {
            d = UserDefaults.standard
        } else {
            d = UserDefaults(suiteName: domain)
        }
        guard let obj = d?.object(forKey: key) else { return nil }
        if let n = obj as? NSNumber { return n.boolValue }
        if let b = obj as? Bool { return b }
        return nil
    }

    @discardableResult
    private static func write(domain: String, key: String, value: Bool) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = ["write", domain, key, "-bool", value ? "true" : "false"]
        do { try p.run(); p.waitUntilExit() } catch { return false }
        return p.terminationStatus == 0
    }

    private static func restartDock() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Dock"]
        try? p.run()
        p.waitUntilExit()
    }

    // MARK: - The three checks

    /// `com.apple.spaces spans-displays`
    /// true  => all your screens are treated as ONE screen (bad, causes blackouts)
    /// false => each screen keeps its own things (good, and the macOS default)
    static func checkBlackDisplays() -> Finding? {
        let spanning = readBool(domain: "com.apple.spaces", key: "spans-displays") ?? false
        guard spanning else { return nil }

        // Never describe a symptom the person cannot be having. With one screen
        // attached there are no "other screens" to go black, so this is a warning
        // about the next time they plug something in, not a report of a problem.
        let multiScreen = NSScreen.screens.count > 1

        return Finding(
            id: "black-displays",
            kind: .blackDisplays,
            severity: multiScreen ? .nowBroken : .willBiteLater,
            headline: multiScreen
                ? "Your other screens go black when something fills the screen."
                : "Your screens will go black when you plug in another one.",
            explanation: multiScreen
                ? """
                  A setting is switched off, so your Mac treats all your screens \
                  as one big one. Make a video full screen and it clears the \
                  others to make room.

                  Switching it back on gives each screen its own windows again.
                  """
                : """
                  A setting is switched off that only matters once you have more \
                  than one screen. While it is off, your Mac treats every screen \
                  you plug in as part of one big one, so a full-screen video \
                  blanks the rest.

                  Nothing is wrong today. Worth switching back on before it \
                  catches you out.
                  """,
            actionLabel: "Fix this for me",
            costWarning: "Your Mac has to log you out and back in before this works. Save anything you are in the middle of first.",
            technicalNote: "com.apple.spaces spans-displays = 1; want 0. 'Displays have separate Spaces' is OFF. Requires logout.",
            repair: {
                write(domain: "com.apple.spaces", key: "spans-displays", value: false)
            }
        )
    }

    /// `NSGlobalDomain AppleSpacesSwitchOnActivate`
    /// Absent or true => opening an app takes you to where its things are (good).
    /// false => the app opens but you are left staring at an empty screen.
    ///
    /// This is the only public lever that makes your Mac follow a thing to the
    /// screenful it is on. There is no way to code around it being off.
    static func checkAppsWontComeForward() -> Finding? {
        let raw = readBool(domain: "NSGlobalDomain", key: "AppleSpacesSwitchOnActivate")
        let switching = raw ?? true   // absent means on
        guard !switching else { return nil }

        return Finding(
            id: "wont-come-forward",
            kind: .appsWontComeForward,
            severity: .nowBroken,
            headline: "You click an app and end up looking at an empty screen.",
            explanation: """
            Your Mac keeps more than one desktop, and shows you one at a time.

            A setting is telling it not to follow an app to the desktop its \
            windows are on. The app opens, just somewhere you are not looking.

            Switching it back on means your Mac takes you there instead of \
            leaving you behind.
            """,
            actionLabel: "Fix this for me",
            costWarning: nil,
            technicalNote: "NSGlobalDomain AppleSpacesSwitchOnActivate = 0; want 1. No public API can force a Space switch for a window you don't own, so this setting is load-bearing.",
            repair: {
                write(domain: "NSGlobalDomain", key: "AppleSpacesSwitchOnActivate", value: true)
            }
        )
    }

    /// `com.apple.dock minimize-to-application`
    /// true => shrunk things vanish inside the app's picture, with no sign they exist.
    /// false => shrunk things get their own picture in the bar (findable).
    static func checkHiddenMinimized() -> Finding? {
        let hiding = readBool(domain: "com.apple.dock", key: "minimize-to-application") ?? false
        guard hiding else { return nil }

        return Finding(
            id: "hidden-minimized",
            kind: .hiddenMinimized,
            severity: .willBiteLater,
            headline: "Windows you shrink down vanish with no way to find them.",
            explanation: """
            Shrink a window and it should get its own icon in the bar at the \
            bottom, so you can click it to bring it back.

            A setting is tucking them inside the app's icon instead. Nothing \
            appears in the bar, so there is no sign the window is still there, \
            and clicking the app often will not restore it.

            Switching it back gives each one its own icon again.
            """,
            actionLabel: "Fix this for me",
            costWarning: nil,
            technicalNote: "com.apple.dock minimize-to-application = 1; want 0. Minimized windows are invisible in the Dock; single-click frequently fails to restore. Contributes to FB21087054 symptoms.",
            repair: {
                let ok = write(domain: "com.apple.dock", key: "minimize-to-application", value: false)
                if ok { restartDock() }
                return ok
            }
        )
    }

    /// Runs every check and sorts so the thing hurting them most is first.
    static func runAll() -> [Finding] {
        [checkBlackDisplays(), checkAppsWontComeForward(), checkHiddenMinimized()]
            .compactMap { $0 }
            .sorted { $0.severity < $1.severity }
    }
}
