import SwiftUI

/// Measures how tall the panel's content wants to be, so it can size to content
/// until the content would run off the screen.
private struct PanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

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
    let onDismiss: () -> Void
    let onQuit: () -> Void

    @State private var contentHeight: CGFloat = 0

    @ViewBuilder
    private var panelContent: some View {
        switch verdict {
        case .needsPermission:
            if awaitingPermission {
                PermissionPendingPanel(
                    onRecheck: onRecheck,
                    onOpenSettings: onOpenPrivacySettings,
                    onDismiss: onDismiss
                )
            } else {
                PermissionPanel(onGrant: onGrantPermission, onLater: onDismiss)
            }
        case .allWell(let when):
            AllWellPanel(lastChecked: when, onRecheck: onRecheck, onDismiss: onDismiss)
        case .somethingWrong(let primary, let also):
            ProblemPanel(finding: primary, alsoFound: also,
                         onRepair: onRepair, onDismiss: onDismiss)
        }
    }

    /// How tall the panel may get before it starts scrolling.
    ///
    /// Positioning cannot save a panel that is taller than the screen, and the
    /// problem panels run to about 630pt. That fits comfortably on this Mac, and
    /// not at all on a small or scaled display, or with Larger Text switched on.
    /// So cap it and let the rest scroll rather than fall off the bottom.
    private var maxPanelHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 800
        return max(320, visible - 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                panelContent
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: PanelHeightKey.self,
                                                   value: g.size.height)
                        }
                    )
            }
            // Sizes to the content until the content outgrows the screen.
            .frame(height: min(max(contentHeight, 1), maxPanelHeight))
            .onPreferenceChange(PanelHeightKey.self) { contentHeight = $0 }

            Divider().overlay(D.hairline)

            // The footer stays put, so Quit is always reachable even when the
            // panel above it is scrolling.
            HStack(spacing: 14) {
                Text("unstray \(Bundle.main.shortVersion)")
                    .font(D.label(11))
                    .foregroundStyle(D.inkFaint)
                if showsSupportLink { SupportLink() }
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

    /// The support link shows only on the all-clear panel.
    ///
    /// The other two panels are in the middle of asking for something — the
    /// permission to work at all, or one press to put right what is broken.
    /// A link about money beside either of those reads as a price on the fix,
    /// and the permission panel spends its whole height earning trust it
    /// cannot afford to spend. The all-clear panel asks for nothing, and it is
    /// the one a person sees almost every time.
    private var showsSupportLink: Bool {
        if case .allWell = verdict { return true }
        return false
    }
}

/// The only place the app asks for anything.
///
/// unstray is free and stays free, so this is a plain link and never a button.
/// A button is the thing to do; this is not. It carries no colour, so it never
/// competes with the answer above it, and it is underlined because at this size
/// nothing else marks it as something you may press.
///
/// The one page collects for four apps and cannot otherwise tell them apart, so
/// `app=unstray` rides along to say which one sent the person. It is the same
/// value everywhere in this repo, and it is never shown to anyone.
private struct SupportLink: View {
    var body: some View {
        Link("Buy me a coffee",
             destination: URL(string: "https://ko-fi.com/initiatorworks?app=unstray")!)
            .font(D.label(11))
            .foregroundStyle(D.inkFaint)
            .underline()
            .help("Opens ko-fi.com in your browser. Entirely optional.")
    }
}

// MARK: - Nothing is wrong
//
// This is the screen people see almost every time, so it gets the most care, not
// the least. It must feel like reassurance rather than an empty state — the
// answer to "is it me?" is "no, and here is proof I looked."

private struct AllWellPanel: View {
    let lastChecked: String
    let onRecheck: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenDiagram(strayCount: 0, tint: D.calm)
                .padding(.top, 2)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.97)
                .usAnimation(appeared)

            VStack(alignment: .leading, spacing: 8) {
                // A quiet mark that everything is accounted for. The only place
                // the calm colour speaks above a whisper.
                HStack(spacing: 7) {
                    Circle()
                        .fill(D.calm)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
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
            .usAnimation(appeared)

            HStack(spacing: 11) {
                // "Done" comes first and is the filled button, because when
                // nothing is wrong the only thing left to do is close this.
                // It must always be here: the rescue key can open this panel
                // sticky, and a sticky panel whose only buttons are "Check
                // again" and "Quit" is a trap — real users got stuck in exactly that.
                Button("Done", action: onDismiss)
                    .buttonStyle(USButton(role: .primary, tint: D.calm))
                Button("Check again", action: onRecheck)
                    .buttonStyle(USButton(role: .quiet))
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
    let onDismiss: () -> Void

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
                        .accessibilityHidden(true)
                    Text(finding.followsOSUpdate ? "Checked after an update" : "Found something")
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

            HStack(spacing: 11) {
                Button(finding.actionLabel) { onRepair(finding) }
                    .buttonStyle(USButton(role: .primary, tint: D.attention))

                // A panel that opened itself must have a visible way out, or it
                // is a trap. Never rely on clicking elsewhere to dismiss it.
                Button("Not now", action: onDismiss)
                    .buttonStyle(USButton(role: .quiet))
            }
            .padding(.top, 2)

            if !alsoFound.isEmpty {
                Text(alsoSentence)
                    .font(D.label(11))
                    .foregroundStyle(D.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, D.pad)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .usAnimation(appeared)
        .onAppear { appeared = true }
    }

    /// After an update, say so — but only as timing, never as blame.
    ///
    /// All we actually know is that macOS changed version since we last looked
    /// and something is wrong now. We do NOT know the update caused it; the
    /// setting may well have been wrong beforehand. Saying "the update did this"
    /// would be inventing a cause, and this app is built on telling people the
    /// truth about their Mac.
    private var explanationText: String {
        guard finding.followsOSUpdate else { return finding.explanation }
        return "Your Mac has been updated since I last looked, so this is a good "
             + "moment to check.\n\n"
             + finding.explanation
    }

    /// Mentions the rest without listing them — a promise, not a queue.
    private var alsoSentence: String {
        alsoFound.count == 1
            ? "There is one more thing to sort out after this one."
            : "There are \(alsoFound.count) more things to sort out after this one."
    }
}
