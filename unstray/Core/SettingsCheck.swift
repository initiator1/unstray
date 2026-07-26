import Foundation

/// Reads the three macOS settings that decide whether your Mac can lose things.
///
/// All three have silently flipped on this machine at least once — `spans-displays`
/// turned itself off during a Tahoe update, blacked out two monitors, and stranded
/// five windows off the edge of every screen. Nobody touched it. That is the whole
/// reason this app exists: the settings drift, and macOS never tells you.
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

        return Finding(
            id: "black-displays",
            kind: .blackDisplays,
            severity: .nowBroken,
            headline: "Your other screens go black when you make a video full screen.",
            explanation: """
            That is not your fault, and nothing is broken.

            A setting got turned off, and while it is off your Mac treats all of \
            your screens as one big screen. So when you fill "the whole screen", \
            it empties the others to make room.

            I can turn that setting back on. Then each screen keeps its own things.
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
            Your Mac can hold several screenfuls of things at once, and it only \
            shows you one at a time.

            Right now a setting is telling your Mac not to take you to where an \
            app's things are. So the app opens — but it opens somewhere you are \
            not looking, and you get left staring at nothing.

            Turning that setting back on makes your Mac take you to the app \
            instead of leaving you behind.
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
            headline: "Things you shrink down disappear with no way to find them.",
            explanation: """
            When you shrink something down to the bar at the bottom of your \
            screen, it normally gets its own little picture there, so you can \
            click it to get it back.

            Right now your Mac is tucking those inside the app's own picture \
            instead. Nothing shows up in the bar, so there is no sign the thing \
            still exists — and clicking the app often will not bring it back.

            Giving them their own picture again makes them easy to find.
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
