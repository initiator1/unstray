import Foundation

/// Whether an app that came forward with nothing to show is broken, or opening.
///
/// Pure, and separate from the watcher, because the wrong answer here is not a
/// cosmetic bug — it accuses a working app in front of the person using it, and
/// offers to act on the accusation.
///
/// ## Why it is so patient
///
/// An app with no window is the ordinary state of an app that is *opening*.
/// Clicking "Update" in an app's own updater replaces it on disk and starts it
/// again, and for a second or two the new copy is running with nothing on
/// screen — indistinguishable, at any single instant, from the macOS bug this
/// watches for. Only elapsed time tells the two apart.
///
/// This was got wrong once. An earlier version gave the app exactly one second
/// and then announced "You clicked ChatGPT and nothing came up", about a second
/// before ChatGPT finished updating and opened its window on another screen. The
/// same mistake had already been found and fixed for a frozen app, and simply
/// never applied here.
enum EmptyAppPatience {

    /// What to do on this look.
    enum Step: Equatable {
        /// Nothing to say. Stop looking.
        case goQuiet
        /// Too early to tell. Look again shortly.
        case keepWaiting
        /// Ask it for a window, the way the Dock is supposed to.
        case askForAWindow
        /// It really has nothing to show. Explain.
        case speak
    }

    /// How often to look again while waiting to see whether an app is broken or
    /// merely busy.
    static let lookAgainEvery: TimeInterval = 0.6

    /// How long to give an app after asking it for a window, before deciding the
    /// asking did not work.
    static let graceAfterAsking: TimeInterval = 2.0

    /// A cap, so an app that never finishes launching is not watched for ever.
    /// About eighteen seconds.
    static let mostLooks = 30

    /// Whether to speak, wait, ask, or go quiet.
    static func step(terminated: Bool,
                     showsSomethingNow: Bool,
                     personMovedOn: Bool,
                     stillStartingUp: Bool,
                     alreadyAsked: Bool,
                     secondsSinceAsking: TimeInterval,
                     looksSoFar: Int) -> Step {
        // It replaced itself, or the person quit it. Nothing exists to report on.
        if terminated { return .goQuiet }
        // A window arrived. This is the ordinary ending, and it is silent.
        if showsSomethingNow { return .goQuiet }
        // They are looking at something else now. The moment has passed.
        if personMovedOn { return .goQuiet }

        let outOfTime = looksSoFar >= mostLooks

        // Still opening. Not broken, just busy — and asking a half-started app
        // for a window achieves nothing and risks poking an updater mid-flight.
        if stillStartingUp && !outOfTime { return .keepWaiting }

        if !alreadyAsked {
            // Never got far enough to ask, and now out of time. The panel says
            // "I asked it to open one and it did not answer", so with nothing
            // asked there is nothing honest to say.
            return outOfTime ? .goQuiet : .askForAWindow
        }
        if secondsSinceAsking >= graceAfterAsking || outOfTime { return .speak }
        return .keepWaiting
    }
}
