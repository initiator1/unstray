import SwiftUI

/// The one thing this app will be remembered by: a little picture of your own
/// screens, drawn to scale from the screens you actually have plugged in.
///
/// When everything is fine, the screens sit calmly side by side.
/// When something is parked off the edge, a small shape floats out past them —
/// so you *see* what happened before you read a single word. For a person who
/// does not know the phrase "off-screen", this picture is the explanation.
///
/// It is drawn from live `NSScreen` data, not decoration: the proportions and
/// arrangement are genuinely yours.
struct ScreenDiagram: View {
    /// Where lost things are, relative to the screens. Empty when all is well.
    var strayCount: Int = 0
    var tint: Color = D.calm

    @State private var drift = false

    private var screens: [CGRect] { NSScreen.screens.map { $0.frame } }

    /// The bounding box of every screen, which we scale to fit the drawing.
    private var bounds: CGRect {
        screens.reduce(CGRect.null) { $0.union($1) }
    }

    var body: some View {
        GeometryReader { geo in
            let b = bounds
            // Room on the LEFT only, for the stray shapes to sit outside the
            // screens. Reserving it on both sides wasted half the canvas on a
            // single-screen Mac — which is most people — and shrank the screen
            // to a stamp. The right edge needs only a normal margin.
            let leftInset: CGFloat = strayCount > 0 ? 62 : 8
            let rightInset: CGFloat = 8
            // One screen is a tall shape with no row to fit into, so it can use
            // nearly the full height. A row of screens needs breathing room.
            let vPad: CGFloat = screens.count == 1 ? 6 : 16
            let scale = (b.width > 0 && b.height > 0)
                ? min((geo.size.width - leftInset - rightInset) / b.width,
                      (geo.size.height - vPad) / b.height)
                : 0
            // Centre within the space left over after the stray gutter.
            let ox = leftInset + (geo.size.width - leftInset - rightInset - b.width * scale) / 2
            let oy = (geo.size.height - b.height * scale) / 2

            ZStack(alignment: .topLeading) {
                // Your screens. Each one is lit from within — a screen that is
                // on, not an empty box. The glow is what makes this read as
                // "your desk" instead of "a diagram".
                ForEach(Array(screens.enumerated()), id: \.offset) { _, f in
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.20), tint.opacity(0.07)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .stroke(tint.opacity(0.85), lineWidth: 1.3)
                        )
                        .shadow(color: tint.opacity(0.35), radius: 7)
                        .frame(width: max(f.width * scale, 6),
                               height: max(f.height * scale, 5))
                        .offset(x: ox + (f.minX - b.minX) * scale,
                                y: oy + (f.minY - b.minY) * scale)
                }

                // The thing that is not on any of them. It drifts, gently,
                // just past the left edge — the visual form of "out there".
                if strayCount > 0 {
                    ForEach(0..<min(strayCount, 3), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(D.attention.opacity(0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .stroke(D.attention, lineWidth: 1.2)
                            )
                            .frame(width: 20, height: 14)
                            .offset(
                                x: (drift ? 0 : 6) + CGFloat(i) * 4,
                                y: oy + 8 + CGFloat(i) * 19
                            )
                            .opacity(1.0 - Double(i) * 0.22)
                    }
                }
            }
            .onAppear {
                guard strayCount > 0,
                      !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                else { return }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
        }
        .frame(height: 92)
        // Said out loud for anyone using VoiceOver. The picture IS the
        // explanation for sighted people, so it has to say the same thing in
        // words rather than announcing a pile of unlabelled shapes.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenDescription)
    }

    /// What this picture means, in the same plain words the panel uses.
    private var spokenDescription: String {
        let n = screens.count
        let screenWord = n == 1 ? "1 screen" : "\(n) screens"
        if strayCount == 0 {
            return "A picture of your \(screenWord). Everything is on a screen you can see."
        }
        let thing = strayCount == 1 ? "1 thing" : "\(strayCount) things"
        return "A picture of your \(screenWord), with \(thing) sitting outside them, "
             + "where no screen can reach."
    }
}
