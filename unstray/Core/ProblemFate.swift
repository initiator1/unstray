import Foundation

/// What to do with a problem this app has already stated out loud.
///
/// Pure, and separate from the record that uses it, for the same reason
/// `EmptyAppPatience` is separate from the watcher: the wrong answer here is not
/// cosmetic. Answering `forget` too readily is how a repair button came to
/// replace a real problem with "Everything is where it should be" — this app's
/// founding failure, committed by this app.
///
/// The rule that carries the weight is the second one. Not being able to check
/// is not the same as there being nothing to find, and only one of those two is
/// safe to assume.
enum ProblemFate: Equatable {
    /// It is genuinely gone. Stop saying it.
    case forget
    /// Cannot tell yet, and saying either thing would be a guess.
    case waitAndSeeAgain
    /// Still true. Keep saying it.
    case keepSaying

    static func of(terminated: Bool,
                   stillStartingUp: Bool,
                   couldCheck: Bool,
                   problemNow: Bool) -> ProblemFate {
        // A dead process cannot still have a problem for the person to solve.
        if terminated { return .forget }

        // Never turn a failed check into an all-clear. Without permission to
        // look, the answer is unknowable, and the last honest answer must stand.
        if !couldCheck { return .keepSaying }

        // A relaunch answers every one of these questions wrongly until it has
        // settled. Keep the record and say nothing until a later pass can judge
        // it fairly. This repo has got that wrong twice already.
        if stillStartingUp { return .waitAndSeeAgain }

        return problemNow ? .keepSaying : .forget
    }
}
