import SwiftUI

/// The look of the app, in one place.
///
/// ## The thinking
///
/// Every tool that tries to solve this problem looks like a control panel:
/// grids of toggles, status lights, dense rows of settings. That is what made
/// them useless to anyone who does not already understand the words. This app
/// is the opposite — it answers one question, in one sentence, with one button.
///
/// The feeling to produce is **relief**, never alarm. Nothing here is an
/// emergency; a thing is merely somewhere you cannot see it, and it is coming
/// back. So there is no red anywhere in this app. The "we found something"
/// colour is warm amber — a lamp being switched on in a dark room, not a
/// warning light.
enum D {

    // MARK: - Colour
    //
    // A screen at night, not a black void. Slightly blue, slightly soft, so the
    // amber and sage read as warm against it.

    static let bg         = Color(red: 0.086, green: 0.098, blue: 0.125)  // deep blue-slate
    static let bgRaised   = Color(red: 0.118, green: 0.133, blue: 0.165)  // cards
    static let bgSunken   = Color(red: 0.063, green: 0.071, blue: 0.094)  // the screen diagram well

    static let ink        = Color(red: 0.945, green: 0.953, blue: 0.973)  // primary text
    static let inkSoft    = Color(red: 0.671, green: 0.702, blue: 0.769)  // explanation text
    static let inkFaint   = Color(red: 0.404, green: 0.435, blue: 0.510)  // timestamps, asides

    /// All is well. A muted sage — present, unshowy, never a "success green".
    static let calm       = Color(red: 0.549, green: 0.702, blue: 0.596)
    /// We found something. Warm amber: a lamp, not an alarm.
    static let attention  = Color(red: 0.933, green: 0.702, blue: 0.400)

    static let hairline   = Color.white.opacity(0.07)

    // MARK: - Type
    //
    // Outfit, per house rules: 100 for large, 200 for medium, 300 for small.
    // The weights are unusually light on purpose — this app speaks quietly.

    static func display(_ size: CGFloat = 30) -> Font { .custom("Outfit", size: size).weight(.thin) }
    static func title(_ size: CGFloat = 20)   -> Font { .custom("Outfit", size: size).weight(.ultraLight) }
    static func body(_ size: CGFloat = 14)    -> Font { .custom("Outfit", size: size).weight(.light) }
    static func label(_ size: CGFloat = 12)   -> Font { .custom("Outfit", size: size).weight(.light) }

    // MARK: - Metrics

    static let panelWidth: CGFloat = 380
    static let pad: CGFloat = 22
    static let radius: CGFloat = 14
}

/// The one button style in the app.
///
/// Filled when it is the thing to do, quiet when it is the way out. Never two
/// loud buttons competing — the person should never have to decide which of two
/// bright things to press.
struct FMButton: ButtonStyle {
    enum Role { case primary, quiet }
    let role: Role
    var tint: Color = D.attention

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(D.body(14))
            .foregroundStyle(role == .primary ? D.bg : D.inkSoft)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(role == .primary ? tint : Color.white.opacity(0.06))
            )
            .opacity(pressed ? 0.75 : 1)
            .scaleEffect(pressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

extension View {
    /// Honours the person's "reduce motion" setting without every caller
    /// having to remember to.
    func fmAnimation<V: Equatable>(_ value: V) -> some View {
        self.animation(
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                ? nil : .spring(response: 0.45, dampingFraction: 0.82),
            value: value
        )
    }
}


extension NSImage {
    /// A coloured copy of a symbol image, for the menu-bar icon. Template
    /// images cannot carry their own colour, and for the attention state the
    /// colour *is* the message.
    func tinted(with color: NSColor) -> NSImage {
        let out = NSImage(size: size)
        out.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: size)
        draw(in: rect)
        rect.fill(using: .sourceAtop)
        out.unlockFocus()
        out.isTemplate = false
        return out
    }
}
