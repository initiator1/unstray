import SwiftUI

/// Asked once, before macOS shows its own frightening dialog.
///
/// ## Why this screen exists
///
/// The system's dialog says the app wants to "control your computer". To
/// someone who has not used a computer much, that sounds like handing over the
/// keys — and the honest reaction is to press No.
///
/// So we go first, and we say the small true thing instead of the big scary
/// one: to move something back onto your screen, an app has to be allowed to
/// move things. That is the whole of it. We say what we will do, we say what we
/// will never do, and only then do we let macOS ask.
///
/// The list of promises is not decoration. It is the part that earns the Yes.
struct PermissionPanel: View {
    let onGrant: () -> Void
    let onLater: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // The diagram in its "reaching out" state: one shape being brought
            // home. Shows what the permission is *for* before we ask for it.
            ScreenDiagram(strayCount: 2, tint: D.attention)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(D.attention)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                    Text("One thing first")
                        .font(D.label(11))
                        .tracking(1.1)
                        .foregroundStyle(D.attention)
                }

                Text("I need your permission\nto move things.")
                    .font(D.display(21))
                    .foregroundStyle(D.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text("""
                To pull something back onto your screen, I have to be allowed to \
                move it. Your Mac will ask you about this in a moment.

                The wording it uses sounds much bigger than what I actually do:
                """)
                    .font(D.body(13.5))
                    .foregroundStyle(D.inkSoft)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // What we do, and what we never do. Concrete beats reassuring.
            VStack(alignment: .leading, spacing: 7) {
                Promise(good: true,  text: "Move things back where you can see them")
                Promise(good: true,  text: "Bring an app to the front when you ask")
                Promise(good: false, text: "Never read what is on your screen")
                Promise(good: false, text: "Never type, click, or send anything")
            }
            .padding(.leading, 1)

            HStack(spacing: 11) {
                Button("Give permission", action: onGrant)
                    .buttonStyle(FMButton(role: .primary, tint: D.attention))
                Button("Not yet", action: onLater)
                    .buttonStyle(FMButton(role: .quiet))
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
}

/// One line of "here is what I will and will not do".
///
/// The two kinds are told apart by shape as well as colour, so the difference
/// survives colour blindness and a dimmed screen.
private struct Promise: View {
    let good: Bool
    let text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: good ? "arrow.right" : "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(good ? D.calm : D.inkSoft)
                .frame(width: 13, height: 13)
                .background(
                    Circle().fill((good ? D.calm : D.inkSoft).opacity(0.14))
                )
            Text(text)
                .font(D.body(13))
                // Both kinds use inkSoft: these four lines are what earn the
                // Yes, so neither the promises nor the "never" lines may be the
                // faintest text on the screen.
                .foregroundStyle(D.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Shown after they press the button but before macOS answers, and whenever
/// permission was refused. Tells them exactly where to go, in the order the
/// buttons actually appear on screen.
struct PermissionPendingPanel: View {
    let onRecheck: () -> Void
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Circle().fill(D.attention).frame(width: 5, height: 5)
                    .accessibilityHidden(true)
                        .accessibilityHidden(true)
                Text("Waiting for you")
                    .font(D.label(11))
                    .tracking(1.1)
                    .foregroundStyle(D.attention)
            }

            Text("Your Mac is asking you\nthe question now.")
                .font(D.display(20))
                .foregroundStyle(D.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("""
            Look for a box that mentions foremac and press Open System Settings, \
            then switch foremac on in the list.

            If the box has already gone, I can take you straight there.
            """)
                .font(D.body(13.5))
                .foregroundStyle(D.inkSoft)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 11) {
                Button("Take me there", action: onOpenSettings)
                    .buttonStyle(FMButton(role: .primary, tint: D.attention))
                Button("I have done it", action: onRecheck)
                    .buttonStyle(FMButton(role: .quiet))
                Button("Later", action: onDismiss)
                    .buttonStyle(FMButton(role: .quiet))
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, D.pad)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }
}
