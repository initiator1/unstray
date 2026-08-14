import Cocoa

/// The panel and the watcher used to be two authors of one verdict. This small
/// record lets the watcher supply evidence while the panel keeps one author.
/// Every call runs on the main thread, so locks would add complexity without
/// protecting anything.
final class OpenProblems {
    static let shared = OpenProblems()

    /// Something the watcher said out loud and has not yet seen disappear.
    struct Seen {
        let appName: String
        let pid: pid_t
        let seenAt: Date
    }

    private var seenByPID: [pid_t: Seen] = [:]
    private var lastKindByPID: [pid_t: Usability.Problem.Kind] = [:]

    /// Records what the watcher could not fix. Keying by pid replaces a prior
    /// look at the same process instead of making the panel count it twice.
    func record(appName: String, pid: pid_t, problem: Usability.Problem) {
        seenByPID[pid] = Seen(appName: appName, pid: pid, seenAt: Date())
        lastKindByPID[pid] = problem.kind
    }

    /// Re-asks every open question and drops what is genuinely gone.
    /// Returns what is still true, oldest first, so the panel is stable.
    func stillTrue() -> [(appName: String, kind: Usability.Problem.Kind)] {
        let ordered = seenByPID.values.sorted {
            if $0.seenAt != $1.seenAt { return $0.seenAt < $1.seenAt }
            return $0.pid < $1.pid
        }
        var answer: [(appName: String, kind: Usability.Problem.Kind)] = []

        for seen in ordered {
            guard let app = NSRunningApplication(processIdentifier: seen.pid) else {
                seenByPID.removeValue(forKey: seen.pid)
                lastKindByPID.removeValue(forKey: seen.pid)
                continue
            }

            let terminated = app.isTerminated
            let couldCheck = WindowRescue.hasPermission
            let stillStartingUp = !terminated && Usability.isStillStartingUp(app)
            let problem = couldCheck && !terminated && !stillStartingUp
                ? Usability.problem(for: app)
                : nil

            switch ProblemFate.of(terminated: terminated,
                                  stillStartingUp: stillStartingUp,
                                  couldCheck: couldCheck,
                                  problemNow: problem != nil) {
            case .forget:
                seenByPID.removeValue(forKey: seen.pid)
                lastKindByPID.removeValue(forKey: seen.pid)

            case .waitAndSeeAgain:
                continue

            case .keepSaying:
                if let problem {
                    lastKindByPID[seen.pid] = problem.kind
                    answer.append((seen.appName, problem.kind))
                } else if let last = lastKindByPID[seen.pid] {
                    answer.append((seen.appName, last))
                }
            }
        }

        return answer
    }
}
