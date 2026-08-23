import Foundation

/// Pure rules for how long a reported app problem has lasted and when its
/// wording should stop describing the moment when it was first noticed.
enum ProblemAge {
    enum Kind {
        case hidden
        case notResponding
        case titleBarOutOfReach
        case pushedOffTheEdge
        case nothingToShow
    }

    struct Wording {
        let headline: String
        let explanation: String
    }

    static let notRespondingPlainAfter: TimeInterval = 120
    static let nothingToShowPlainAfter: TimeInterval = 300

    static func isPlain(kind: Kind, age: TimeInterval) -> Bool {
        switch kind {
        case .notResponding:
            return age >= notRespondingPlainAfter
        case .nothingToShow, .hidden:
            return age >= nothingToShowPlainAfter
        case .titleBarOutOfReach, .pushedOffTheEdge:
            return false
        }
    }

    static func inWords(_ age: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.day, .hour, .minute]
        return formatter.string(from: max(0, age)) ?? "0 minutes"
    }

    static func firstSighting(existing: Date?, sameKind: Bool, now: Date) -> Date {
        if sameKind, let existing { return existing }
        return now
    }

    /// The two findings whose words age. WindowScan remains the only place that
    /// turns this wording into a Finding and attaches an action.
    static func wording(appName: String, kind: Kind,
                        age: TimeInterval) -> Wording {
        switch kind {
        case .notResponding:
            if isPlain(kind: kind, age: age) {
                let age = inWords(age)
                return Wording(
                    headline: "\(appName) has stopped answering.",
                    explanation: """
                    \(appName) stopped answering about \(age) ago and has not come back. \
                    You can force it to quit and reopen it, though you may lose anything \
                    you had not saved.

                    Press Command-Option-Escape to open the Force Quit window, pick \
                    \(appName), and press Force Quit. The button below opens the same window.
                    """
                )
            }
            return Wording(
                headline: "\(appName) has stopped answering.",
                explanation: """
                Clicking again will not wake it up. \(appName) is still running, it \
                has just stopped listening, so nothing you click reaches it.

                It may come back on its own. If it does not, you can force it to quit \
                and reopen it, though you may lose anything you had not saved.

                Press Command-Option-Escape to open the Force Quit window, pick \
                \(appName), and press Force Quit. The button below opens the same window.
                """
            )

        case .nothingToShow, .hidden:
            if isPlain(kind: kind, age: age) {
                let age = inWords(age)
                return Wording(
                    headline: "\(appName) has had nothing on screen for about \(age).",
                    explanation: """
                    This is a bug in macOS.

                    \(appName) really is open. Your Mac just never gave it a window to \
                    show you, and did not notice.

                    I asked it to open one and it did not answer. Quitting \(appName) and \
                    opening it again usually sorts it out.
                    """
                )
            }
            return Wording(
                headline: "You clicked \(appName) and nothing came up.",
                explanation: """
                This is a bug in macOS, and clicking more times will not help.

                \(appName) really is open. Your Mac just never gave it a window to \
                show you, and did not notice.

                I asked it to open one and it did not answer. Quitting \(appName) and \
                opening it again usually sorts it out.
                """
            )

        case .titleBarOutOfReach, .pushedOffTheEdge:
            preconditionFailure("Only moment-specific findings have aged wording")
        }
    }
}
