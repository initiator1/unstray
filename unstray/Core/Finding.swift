import Foundation

/// One thing the Mac is doing to the person, described the way they experience it.
///
/// Every user-facing string on a Finding is written to `docs/plain-language.md`.
/// Nothing here may contain a coordinate, a window ID, an error code, a defaults
/// key, or a Feedback number — those live in `technicalNote`, which is written to
/// the log and never shown on screen.
struct Finding: Identifiable, Equatable {
    enum Kind: String {
        case blackDisplays          // spans-displays turned off
        case appsWontComeForward    // AppleSpacesSwitchOnActivate turned off
        case hiddenMinimized        // minimize-to-application turned on
        case strandedWindows        // windows parked where no screen can reach
        case appShowsNothing        // app is open and in front but has no window
    }

    /// How much this is hurting them right now. Order matters: the app shows the
    /// worst one first, and only that one.
    enum Severity: Int, Comparable {
        case nowBroken = 0      // they can see this happening today
        case willBiteLater = 1  // fine now, but set up to fail
        static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
    }

    let id: String
    let kind: Kind
    let severity: Severity

    /// What they noticed. Written as the symptom, never the cause.
    /// Example: "Your other screens go black when you make a video full screen."
    let headline: String

    /// Set when a macOS update is what caused this. Answers the question the
    /// person is actually asking — "why has this started happening now?" —
    /// which is otherwise the most bewildering part of the whole experience.
    var blamesOSUpdate: Bool = false

    /// Why it is happening, in a few short lines. Must survive the read-aloud test.
    let explanation: String

    /// The verb on the button. Something they already know: "Fix this for me".
    let actionLabel: String

    /// Shown *before* they press the button, never after. nil when there is no cost.
    /// Example: "Your Mac needs to log you out and back in."
    let costWarning: String?

    /// For the log and for Aria. Never rendered on screen.
    let technicalNote: String

    /// Applies the repair. Returns true if the change landed.
    let repair: () -> Bool

    static func == (a: Finding, b: Finding) -> Bool { a.id == b.id }
}

/// The single answer the app gives when it opens.
enum Verdict: Equatable {
    /// We have not been given permission to move things yet, so we cannot do
    /// the job at all. This outranks everything else — there is no point
    /// reporting problems we are unable to fix.
    case needsPermission

    /// Nothing is wrong. This is what people see almost every time, so it gets
    /// the most design care, not the least.
    case allWell(lastCheckedDescription: String)

    /// Something is wrong. We show exactly one thing — the worst one — because
    /// a list of problems is a control panel, and a control panel is what every
    /// other tool got wrong.
    case somethingWrong(primary: Finding, alsoFound: [Finding])

    var findings: [Finding] {
        switch self {
        case .needsPermission, .allWell: return []
        case .somethingWrong(let p, let rest): return [p] + rest
        }
    }
}
