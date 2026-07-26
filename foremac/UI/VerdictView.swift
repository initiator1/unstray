import SwiftUI

/// The whole app, as far as a person is concerned: one answer to one question.
///
/// The question is "is anything wrong right now?" — because that is the state a
/// person is in when they reach for this. Not "show me my settings". They have
/// noticed something odd and want to know whether it is them.
///
/// So there is no dashboard, no list, no tabs. One answer, and at most one thing
/// to press.
struct VerdictView: View {
    let verdict: Verdict
    let awaitingPermission: Bool
    let onRepair: (Finding) -> Void
    let onRecheck: () -> Void
    let onGrantPermission: () -> Void
    let onOpenPrivacySettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch verdict {
            case .needsPermission:
                if awaitingPermission {
                    PermissionPendingPanel(
                        onRecheck: onRecheck,
                        onOpenSettings: onOpenPrivacySettings
                    )
                } else {
                    PermissionPanel(onGrant: onGrantPermission, onLater: onQuit)
                }
            case .allWell(let when):
                AllWellPanel(lastChecked: when, onRecheck: onRecheck)
            case .somethingWrong(let primary, let also):
                ProblemPanel(finding: primary, alsoFound: also, onRepair: onRepair)
            }

            Divider().overlay(D.hairline)

            HStack(spacing: 14) {
                Text("foremac")
                    .font(D.label(11))
                    .foregroundStyle(D.inkFaint)
                Spacer()
                Button("Quit", action: onQuit)
                    .buttonStyle(.plain)
                    .font(D.label(11))
                    .foregroundStyle(D.inkFaint)
            }
            .padding(.horizontal, D.pad)
            .padding(.vertical, 11)
        }
        .frame(width: D.panelWidth)
        .background(D.bg)
    }
}

// MARK: - Nothing is wrong
//
// This is the screen BOSS sees almost every time, so it gets the most care, not
// the least. It must feel like reassurance rather than an empty state — the
// answer to "is it me?" is "no, and here is proof I looked."

private struct AllWellPanel: View {
    let lastChecked: String
    let onRecheck: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenDiagram(strayCount: 0, tint: D.calm)
                .padding(.top, 2)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.97)
                .fmAnimation(appeared)

            VStack(alignment: .leading, spacing: 8) {
                // A quiet mark that everything is accounted for. The only place
                // the calm colour speaks above a whisper.
                HStack(spacing: 7) {
                    Circle()
                        .fill(D.calm)
                        .frame(width: 5, height: 5)
                    Text("All clear")
                        .font(D.label(11))
                        .tracking(1.1)
                        .foregroundStyle(D.calm)
                }

                Text("Everything is where\nit should be.")
                    .font(D.display(25))
                    .foregroundStyle(D.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(screenSentence)
                    .font(D.body(13.5))
                    .foregroundStyle(D.inkSoft)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .fmAnimation(appeared)

            HStack(spacing: 12) {
                Button("Check again", action: onRecheck)
                    .buttonStyle(FMButton(role: .quiet))
                Text(lastChecked)
                    .font(D.label(11))
                    .foregroundStyle(D.inkFaint)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, D.pad)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .onAppear { appeared = true }
    }

    /// Names what was actually checked, in their words. Proof of work, without
    /// a checklist — "I looked at your 3 screens" beats three green ticks.
    private var screenSentence: String {
        let n = NSScreen.screens.count
        let screens = n == 1 ? "your screen" : "all \(n) of your screens"
        return "I looked at \(screens) and at everything you have open. Nothing is hidden, and nothing has wandered off where you cannot reach it."
    }
}

// MARK: - Something is wrong
//
// One problem at a time — the worst one. A list of problems is a control panel,
// and a control panel is what every other tool got wrong.

private struct ProblemPanel: View {
    let finding: Finding
    let alsoFound: [Finding]
    let onRepair: (Finding) -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenDiagram(
                strayCount: finding.kind == .strandedWindows ? 3 : 0,
                tint: D.attention
            )
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                // Mirrors "All clear" on the healthy screen, so the two states
                // are recognisably the same app answering the same question.
                HStack(spacing: 7) {
                    Circle()
                        .fill(D.attention)
                        .frame(width: 5, height: 5)
                    Text(finding.blamesOSUpdate ? "Your Mac just updated" : "Found something")
                        .font(D.label(11))
                        .tracking(1.1)
                        .foregroundStyle(D.attention)
                }

                Text(finding.headline)
                    .font(D.display(20))
                    .foregroundStyle(D.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(explanationText)
                    .font(D.body(13.5))
                    .foregroundStyle(D.inkSoft)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The cost is stated BEFORE the button, never after. Nobody should
            // discover they are being logged out by being logged out.
            if let cost = finding.costWarning {
                HStack(alignment: .top, spacing: 9) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(D.attention.opacity(0.75))
                        .frame(width: 2.5)
                    Text(cost)
                        .font(D.body(12.5))
                        .foregroundStyle(D.inkSoft)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 13) {
                Button(finding.actionLabel) { onRepair(finding) }
                    .buttonStyle(FMButton(role: .primary, tint: D.attention))

                if !alsoFound.isEmpty {
                    Text(alsoSentence)
                        .font(D.label(11))
                        .foregroundStyle(D.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, D.pad)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .fmAnimation(appeared)
        .onAppear { appeared = true }
    }

    /// When an update caused this, that fact goes first — it is the answer to
    /// "why is this happening today, when it was fine yesterday?"
    private var explanationText: String {
        guard finding.blamesOSUpdate else { return finding.explanation }
        return "Your Mac installed an update, and the update changed one of "
             + "its own settings without telling you.\n\n"
             + finding.explanation
    }

    /// Mentions the rest without listing them — a promise, not a queue.
    private var alsoSentence: String {
        alsoFound.count == 1
            ? "There is one more thing to sort out after this one."
            : "There are \(alsoFound.count) more things to sort out after this one."
    }
}
