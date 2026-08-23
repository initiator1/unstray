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
        let now = Date()
        let seenAt = ProblemAge.firstSighting(
            existing: seenByPID[pid]?.seenAt,
            sameKind: lastKindByPID[pid] == problem.kind,
            now: now
        )
        seenByPID[pid] = Seen(appName: appName, pid: pid, seenAt: seenAt)
        lastKindByPID[pid] = problem.kind
    }

    /// Re-asks every open question and drops what is genuinely gone.
    /// Returns what is still true, oldest first, so the panel is stable.
    func stillTrue() -> [(appName: String, kind: Usability.Problem.Kind,
                          since: Date)] {
        let ordered = seenByPID.values.sorted {
            if $0.seenAt != $1.seenAt { return $0.seenAt < $1.seenAt }
            return $0.pid < $1.pid
        }
        var answer: [(appName: String, kind: Usability.Problem.Kind,
                      since: Date)] = []

        for seen in ordered {
            guard let app = NSRunningApplication(processIdentifier: seen.pid) else {
                forget(seen)
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
                forget(seen)

            case .waitAndSeeAgain:
                continue

            case .keepSaying:
                if let problem {
                    let now = Date()
                    let since = ProblemAge.firstSighting(
                        existing: seen.seenAt,
                        sameKind: lastKindByPID[seen.pid] == problem.kind,
                        now: now
                    )
                    if since != seen.seenAt {
                        seenByPID[seen.pid] = Seen(appName: seen.appName,
                                                   pid: seen.pid,
                                                   seenAt: since)
                    }
                    lastKindByPID[seen.pid] = problem.kind
                    answer.append((seen.appName, problem.kind, since))
                } else if let last = lastKindByPID[seen.pid] {
                    answer.append((seen.appName, last, seen.seenAt))
                }
            }
        }

        return answer
    }

    private func forget(_ seen: Seen) {
        guard let kind = lastKindByPID[seen.pid] else {
            seenByPID.removeValue(forKey: seen.pid)
            return
        }
        seenByPID.removeValue(forKey: seen.pid)
        lastKindByPID.removeValue(forKey: seen.pid)
        RepairLog.write(event: "problem_cleared", detail: [
            "problem": logName(kind),
            "age": max(0, Int(Date().timeIntervalSince(seen.seenAt)))
        ])
    }

    private func logName(_ kind: Usability.Problem.Kind) -> String {
        switch kind {
        case .hidden:             return "hidden"
        case .notResponding:      return "notResponding"
        case .titleBarOutOfReach: return "titleBarOutOfReach"
        case .pushedOffTheEdge:   return "pushedOffTheEdge"
        case .nothingToShow:      return "nothingToShow"
        }
    }
}
