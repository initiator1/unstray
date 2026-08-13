import Cocoa

/// Tests for the pure logic — the parts that decide whether the app is right or
/// wrong about your Mac. No UI, no permissions, no real windows: these run
/// anywhere in under a second.
///
///     ./run-tests.sh
///
/// Deliberately dependency-free. A menu-bar app built with swiftc does not need
/// a test framework to check arithmetic and string logic, and adding one would
/// be more machinery than the thing being tested.

var failures = 0
var checks = 0

func check(_ name: String, _ condition: Bool, _ detail: String = "") {
    checks += 1
    if condition {
        print("  ok   \(name)")
    } else {
        failures += 1
        print("  FAIL \(name)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

// MARK: - Does a window touch any screen?
//
// This separates windows stranded past every screen from windows that still
// touch one. ScreenSpace makes the stronger usability decision below.

func unreachable(_ r: CGRect, _ screens: [CGRect]) -> Bool {
    ScreenSpace.visiblePart(of: r, screens: screens).isNull
}

func testReachability() {
    print("\nreachability")
    let one = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
    let three = [
        CGRect(x: 0, y: 0, width: 1168, height: 755),
        CGRect(x: -1920, y: -325, width: 1920, height: 1080),
        CGRect(x: 1168, y: -325, width: 1920, height: 1080)
    ]

    check("window on the only screen is reachable",
          !unreachable(CGRect(x: 100, y: 100, width: 600, height: 400), one))
    check("window past the right edge is unreachable",
          unreachable(CGRect(x: 3000, y: 100, width: 600, height: 400), one))
    check("window at a disconnected screen's old spot is unreachable",
          unreachable(CGRect(x: -2466, y: 1048, width: 586, height: 488), one))
    check("window half on screen is still reachable",
          !unreachable(CGRect(x: -300, y: 100, width: 600, height: 400), one),
          "partly visible means the person can still grab it")
    check("window touching only by one pixel is reachable",
          !unreachable(CGRect(x: 1439, y: 100, width: 600, height: 400), one))

    check("window on the far-left of three screens is reachable",
          !unreachable(CGRect(x: -1800, y: 0, width: 600, height: 400), three))
    check("window beyond all three screens is unreachable",
          unreachable(CGRect(x: -12000, y: 12485, width: 480, height: 270), three))
    check("gap between screens is still unreachable",
          unreachable(CGRect(x: 200, y: -900, width: 300, height: 200), three),
          "above the built-in display, outside every frame")
}

// MARK: - What counts as a real window
//
// Getting this wrong produced eight false alarms in an early version: menu-bar
// helpers and toolbars were reported as lost windows.

func isRealWindow(width: CGFloat, height: CGFloat, layer: Int) -> Bool {
    layer == 0 && width >= 200 && height >= 150
}

func testWindowFiltering() {
    print("\nwindow filtering")
    check("a normal window counts", isRealWindow(width: 586, height: 488, layer: 0))
    check("a 47pt browser toolbar does not",
          !isRealWindow(width: 1168, height: 47, layer: 0))
    check("a small helper panel does not",
          !isRealWindow(width: 312, height: 137, layer: 0))
    check("a non-zero layer does not", !isRealWindow(width: 600, height: 400, layer: 25),
          "layer 25 is a popover, not a document window")
    check("exactly at the threshold counts",
          isRealWindow(width: 200, height: 150, layer: 0))
}

// MARK: - Settings interpretation
//
// The three flags, and what "absent" means for each. Getting a default backwards
// makes the app confidently report the opposite of the truth.

func blackDisplaysBroken(_ raw: Bool?) -> Bool { raw ?? false }
func appsWontComeForwardBroken(_ raw: Bool?) -> Bool { !(raw ?? true) }
func hiddenMinimizedBroken(_ raw: Bool?) -> Bool { raw ?? false }

func testSettings() {
    print("\nsettings interpretation")
    check("spans-displays absent means fine", !blackDisplaysBroken(nil))
    check("spans-displays true means broken", blackDisplaysBroken(true))
    check("spans-displays false means fine", !blackDisplaysBroken(false))

    check("switch-on-activate absent means fine", !appsWontComeForwardBroken(nil),
          "macOS defaults this ON, so absent is healthy")
    check("switch-on-activate false means broken", appsWontComeForwardBroken(false))
    check("switch-on-activate true means fine", !appsWontComeForwardBroken(true))

    check("minimize-to-application absent means fine", !hiddenMinimizedBroken(nil))
    check("minimize-to-application true means broken", hiddenMinimizedBroken(true))
}

// MARK: - Which problem gets shown
//
// Only one is shown at a time, and it must be the one hurting them most.

func testSeverityOrder() {
    print("\nseverity order")
    let nowBroken = 0, willBiteLater = 1
    let sorted = [willBiteLater, nowBroken, willBiteLater].sorted()
    check("a problem happening now outranks one that will bite later",
          sorted.first == nowBroken)
}

// MARK: - Has macOS changed under us
//
// The recurring job. Must fire exactly once per update, and never on first run.

func didUpdate(last: String?, now: String) -> Bool {
    guard let last else { return false }
    return last != now
}

func testVersionDrift() {
    print("\nmacOS version drift")
    check("first run is not an update", !didUpdate(last: nil, now: "26.5.2"),
          "no stored version means we have simply never looked before")
    check("same version is not an update", !didUpdate(last: "26.5.2", now: "26.5.2"))
    check("a changed version is an update", didUpdate(last: "26.4.0", now: "26.5.2"))
    check("a downgrade also counts as a change", didUpdate(last: "26.5.2", now: "26.4.0"))
}

// MARK: - Naming what is lost
//
// The headline names actual apps, because "your Notes" means something to a
// person and "3 windows" does not.

func subject(_ names: [String]) -> String {
    switch names.count {
    case 1:  return "\(names[0]) is"
    case 2:  return "\(names[0]) and \(names[1]) are"
    default: return "\(names[0]), \(names[1]), and \(names.count - 2) other app\(names.count - 2 == 1 ? "" : "s") are"
    }
}

func testHeadlines() {
    print("\nheadline wording")
    check("one app", subject(["Notes"]) == "Notes is")
    check("two apps", subject(["Notes", "Safari"]) == "Notes and Safari are")
    check("three apps says 'one other thing'",
          subject(["Notes", "Safari", "Mail"]).hasSuffix("and 1 other app are"))
    check("four apps pluralises",
          subject(["Notes", "Safari", "Mail", "Music"]).hasSuffix("and 2 other apps are"))
}

// MARK: - Screen picture layout
//
// Regression guard for the single-display bug: the stray gutter belongs on the
// left only, or a one-screen Mac draws its screen as a stamp.

func diagramWidth(screenW: CGFloat, screenH: CGFloat, count: Int, stray: Bool) -> CGFloat {
    let geoW: CGFloat = 336, geoH: CGFloat = 92
    let left: CGFloat = stray ? 62 : 8, right: CGFloat = 8
    let vPad: CGFloat = count == 1 ? 6 : 16
    let scale = min((geoW - left - right) / screenW, (geoH - vPad) / screenH)
    return screenW * scale
}

func testDiagram() {
    print("\nscreen picture")
    let single = diagramWidth(screenW: 1440, screenH: 900, count: 1, stray: false)
    check("a single screen fills a useful width", single > 130,
          "got \(Int(single))pt — was 121pt before the gutter fix")
    let singleStray = diagramWidth(screenW: 1440, screenH: 900, count: 1, stray: true)
    check("a stray shape does not shrink the single screen",
          abs(single - singleStray) < 1)
    let wide = diagramWidth(screenW: 5008, screenH: 1080, count: 3, stray: false)
    check("three screens still fit across", wide <= 320)
}

// MARK: - Can you actually use it?
//
// Existence is not usability. These guard the class of bug that let CotEditor
// through: a window can exist and still be no use to anyone.

func titleBarReachable(_ r: CGRect, _ screens: [CGRect]) -> Bool {
    let bar = CGRect(x: r.minX, y: r.minY, width: r.width, height: 30)
    return screens.contains { $0.intersects(bar) }
}

func testTitleBarReach() {
    print("\ntitle bar reachability")
    let one = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
    check("a normal window can be grabbed",
          titleBarReachable(CGRect(x: 100, y: 100, width: 800, height: 600), one))
    check("5pt above the top is still grabbable",
          titleBarReachable(CGRect(x: 100, y: -5, width: 800, height: 600), one),
          "part of the strip is still on screen")
    check("40pt above the top cannot be grabbed",
          !titleBarReachable(CGRect(x: 100, y: -40, width: 800, height: 600), one),
          "the window is visible but there is nothing left to drag")
    check("flush with the top edge is grabbable",
          titleBarReachable(CGRect(x: 100, y: 0, width: 800, height: 600), one))
    check("far above the screen cannot be grabbed",
          !titleBarReachable(CGRect(x: 100, y: -500, width: 800, height: 600), one))
}

func testUsabilityVsExistence() {
    print("\nusability is not existence")
    let one = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
    // The CotEditor case: leftovers exist, inside the screen, and are useless.
    let leftover = CGRect(x: 0, y: 0, width: 1168, height: 26)
    check("a 26pt strip is not something to look at",
          !isRealWindow(width: leftover.width, height: leftover.height, layer: 0),
          "this exact shape made an early version report 'all clear'")
    check("a 26pt strip does intersect the screen, which is why size must be checked",
          one.contains { $0.intersects(leftover) },
          "geometry alone would call this healthy")
}

// MARK: - Is enough of the window left to use?
//
// These tests call the shipped ScreenSpace code. The measured Epson rectangle
// is the regression case: its 40pt corner exists, but a person cannot use it.

func testScreenSpace() {
    print("\nscreen coordinates and usable window area")
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let one = [screen]

    let source = CGRect(x: -300, y: 1400, width: 434, height: 700)
    check("flipping a rectangle twice restores it",
          ScreenSpace.flip(ScreenSpace.flip(source, primaryTop: 1080),
                           primaryTop: 1080) == source)

    let epson = CGRect(x: 1880, y: 363, width: 434, height: 700)
    let epsonVisible = ScreenSpace.visiblePart(of: epson, screens: one)
    check("the measured Epson sliver is 40pt wide and unusable",
          epsonVisible.width == 40 && !ScreenSpace.isReachable(epson, screens: one))

    let halfOff = CGRect(x: 1703, y: 300, width: 434, height: 700)
    check("217pt left on screen remains reachable",
          ScreenSpace.visiblePart(of: halfOff, screens: one).width == 217
            && ScreenSpace.isReachable(halfOff, screens: one))

    let fullyOn = CGRect(x: 200, y: 200, width: 800, height: 600)
    check("a window fully on screen remains reachable",
          ScreenSpace.isReachable(fullyOn, screens: one))

    let nowhere = CGRect(x: 3000, y: 300, width: 434, height: 700)
    check("a window touching no screen has no visible part",
          ScreenSpace.visiblePart(of: nowhere, screens: one).isNull
            && !ScreenSpace.isReachable(nowhere, screens: one))

    let sideBySide = [screen, CGRect(x: 1920, y: 0, width: 1920, height: 1080)]
    let spanning = CGRect(x: 1800, y: 300, width: 434, height: 700)
    check("a window spanning two screens stays reachable",
          ScreenSpace.visiblePart(of: spanning, screens: sideBySide).width == 434
            && ScreenSpace.isReachable(spanning, screens: sideBySide))

    let slidOrigin = ScreenSpace.slideIntoView(epson, screens: one, preferred: screen)
    let slid = CGRect(origin: slidOrigin, size: epson.size)
    check("the Epson window slides fully inside and keeps its y position",
          slid.minX >= screen.minX && slid.maxX <= screen.maxX
            && slid.minY >= screen.minY && slid.maxY <= screen.maxY
            && slidOrigin.y == epson.minY)

    let tooTall = CGRect(x: 200, y: 300, width: 800, height: 1400)
    let pinned = ScreenSpace.slideIntoView(tooTall, screens: one, preferred: screen)
    check("a window taller than its screen pins to the top",
          pinned.x == tooTall.minX && pinned.y == screen.minY)
}

// MARK: - Where the panel is allowed to sit
//
// Three monitors side by side do not make one big rectangle. A tall monitor next
// to a shorter one leaves dead space above the shorter one, and a panel near the
// tall monitor's top-right corner spills into that gap and gets cut in half.
// That is the real layout this was reported on.

// This tests the SHIPPED PanelPlacement, compiled in by run-tests.sh. It used to
// hold a copy of the arithmetic instead, which meant deleting the real clamp
// altogether left every test green. A guard that cannot fail is not a guard.

typealias Display = PanelPlacement.Display

func inside(_ r: CGRect, _ v: CGRect) -> Bool {
    r.minX >= v.minX && r.maxX <= v.maxX && r.minY >= v.minY && r.maxY <= v.maxY
}

/// The panel as macOS actually hands it over: 380x630 of panel inside a window
/// frame of 406x656, with 13pt of transparent shadow on every side. Measured.
let panelWindow = CGSize(width: 406, height: 656)
let panelShadow: CGFloat = 13

/// A display written the way macOS reports it: the menu bar comes off the top,
/// and the Dock off the bottom of whichever display is showing it.
func display(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
             menuBar: CGFloat = 27, dock: CGFloat = 0) -> Display {
    let frame = CGRect(x: x, y: y, width: w, height: h)
    return Display(frame: frame,
                   visible: CGRect(x: x, y: y + dock,
                                   width: w, height: h - menuBar - dock))
}

// Douglas's real desks, read out of macOS's own record of them
// (~/Library/Preferences/ByHost/com.apple.windowserver.displays.*.plist) and
// converted from Core Graphics' top-left origin to AppKit's bottom-left one by
// reflecting about the PRIMARY display's height — which is the conversion that
// is invisibly right on one monitor and wrong on every other.

/// Three across: 1920x1080 either side of the 1168x755 built-in.
let threeAcross = [
    display(0, 0, 1168, 755),          // [0] built-in, primary
    display(-1920, -325, 1920, 1080),  // [1] left
    display(1168, -325, 1920, 1080)    // [2] right
]

/// One monitor above and to the left, one to the right. Real dead space here:
/// nothing exists above the right-hand monitor.
let oneAbove = [
    display(0, 0, 1168, 755),          // [0] built-in, primary
    display(-234, 755, 1920, 1080),    // [1] above and left
    display(1168, -325, 1920, 1080)    // [2] right
]

/// One monitor below and to the right of a 1920x1080 primary.
let oneBelow = [
    display(0, 0, 1920, 1080),         // [0] primary
    display(1237, -967, 1496, 967),    // [1] below and right
    display(1920, 0, 1920, 1080)       // [2] right
]

/// Mixed Retina and non-Retina, three across. Backing scale never enters this
/// arithmetic — AppKit reports every frame in points — and that is exactly why
/// a 1x monitor beside two 2x ones must not need a special case.
let mixedScaling = [
    display(0, 0, 1168, 755),          // [0] built-in, 2x, primary
    display(1168, -325, 1920, 1080),   // [1] middle, 1x
    display(3088, -325, 1920, 1080)    // [2] right, 2x
]

let allLayouts: [(String, [Display])] = [
    ("three across", threeAcross),
    ("one above", oneAbove),
    ("one below", oneBelow),
    ("mixed Retina/non-Retina", mixedScaling)
]

func testAnchorIsChecked() {
    print("\nis the menu-bar icon really there")

    // Measured on this Mac: a menu-bar manager hides an icon by parking its
    // window off the left edge of everything, while still reporting it visible.
    let parked = CGRect(x: -10093, y: 729, width: 28, height: 26)
    check("an icon parked off every screen is not a usable anchor",
          !PanelPlacement.isUsableAnchor(parked, displays: threeAcross),
          "x=-10093 is 8173pt left of the leftmost monitor")

    // Measured: read too early, before the status bar has laid out.
    let notYetLaidOut = CGRect(x: 0, y: 0, width: 28, height: 0)
    check("an icon with no height yet is not a usable anchor",
          !PanelPlacement.isUsableAnchor(notYetLaidOut, displays: threeAcross),
          "its corner sits inside the primary screen, so contains() alone says yes")

    check("no icon at all is not a usable anchor",
          !PanelPlacement.isUsableAnchor(nil, displays: threeAcross))

    // A real icon in the left monitor's menu bar.
    let realIcon = CGRect(x: -400, y: 729, width: 28, height: 26)
    check("an icon actually in a menu bar is a usable anchor",
          PanelPlacement.isUsableAnchor(realIcon, displays: threeAcross))
}

func testTargetDisplay() {
    print("\nwhich screen the panel goes to")

    let parked = CGRect(x: -10093, y: 729, width: 28, height: 26)
    let onLeftMonitor = CGPoint(x: -900, y: 300)
    let onRightMonitor = CGPoint(x: 2000, y: 300)

    check("a real icon decides the screen",
          PanelPlacement.targetDisplay(anchor: CGRect(x: 2500, y: 729, width: 28, height: 26),
                                       pointer: onLeftMonitor,
                                       displays: threeAcross) == 2,
          "icon on the right monitor beats a pointer on the left")

    check("a parked icon falls through to the screen the pointer is on",
          PanelPlacement.targetDisplay(anchor: parked, pointer: onLeftMonitor,
                                       displays: threeAcross) == 1,
          "this is the case that put the panel on the wrong monitor")

    check("a parked icon and a pointer on the right monitor picks the right monitor",
          PanelPlacement.targetDisplay(anchor: parked, pointer: onRightMonitor,
                                       displays: threeAcross) == 2)

    check("with nothing to go on, the primary screen",
          PanelPlacement.targetDisplay(anchor: parked, pointer: CGPoint(x: -99999, y: -99999),
                                       displays: threeAcross) == 0)

    check("no screens at all is answered honestly, not guessed",
          PanelPlacement.targetDisplay(anchor: nil, pointer: nil, displays: []) == nil)
}

func testPanelIsAlwaysOnItsScreen() {
    print("\nthe panel never hangs off the edge")

    // Every edge and every corner of every screen in every layout, with the icon
    // hidden — the state this Mac is actually in.
    var cases = 0
    var worst = ""
    for (name, layout) in allLayouts {
        for (i, d) in layout.enumerated() {
            let f = d.frame
            let spots: [(String, CGPoint)] = [
                ("top-left corner",     CGPoint(x: f.minX + 1,  y: f.maxY - 1)),
                ("top-right corner",    CGPoint(x: f.maxX - 1,  y: f.maxY - 1)),
                ("bottom-left corner",  CGPoint(x: f.minX + 1,  y: f.minY + 1)),
                ("bottom-right corner", CGPoint(x: f.maxX - 1,  y: f.minY + 1)),
                ("top edge",            CGPoint(x: f.midX,      y: f.maxY - 1)),
                ("bottom edge",         CGPoint(x: f.midX,      y: f.minY + 1)),
                ("left edge",           CGPoint(x: f.minX + 1,  y: f.midY)),
                ("right edge",          CGPoint(x: f.maxX - 1,  y: f.midY))
            ]
            for (where_, pointer) in spots {
                cases += 1
                guard let rect = PanelPlacement.panelRect(
                    size: panelWindow,
                    anchor: CGRect(x: -10093, y: 729, width: 28, height: 26),
                    pointer: pointer,
                    displays: layout,
                    shadow: panelShadow)
                else {
                    worst = "\(name) screen[\(i)] \(where_): no rect at all"
                    continue
                }
                let seen = PanelPlacement.visiblePart(of: rect, shadow: panelShadow)
                if !inside(seen, d.visible) {
                    worst = "\(name) screen[\(i)] \(where_): panel \(seen) is not inside \(d.visible)"
                }
                // And it must not stray onto the monitor next door.
                for (j, other) in layout.enumerated() where j != i {
                    if seen.intersects(other.frame) {
                        worst = "\(name) screen[\(i)] \(where_): panel crosses onto screen[\(j)]"
                    }
                }
            }
        }
    }
    check("every edge and corner of every screen keeps the panel fully on it",
          worst.isEmpty, worst)
    check("that covered a real number of positions", cases == 96, "\(cases) positions")
}

func testPanelFollowsAVisibleIcon() {
    print("\nthe panel hangs under the icon when there is one")

    // Icon near the right-hand end of the LEFT monitor's menu bar — the corner
    // the bug was reported in. The panel is wider than the room left beside it.
    let icon = CGRect(x: -60, y: 729, width: 28, height: 26)
    let d = threeAcross[1]
    guard let rect = PanelPlacement.panelRect(size: panelWindow, anchor: icon,
                                              pointer: CGPoint(x: -60, y: 740),
                                              displays: threeAcross,
                                              shadow: panelShadow) else {
        return check("a panel is produced for the left monitor", false)
    }
    let seen = PanelPlacement.visiblePart(of: rect, shadow: panelShadow)

    check("hung under an icon at the left monitor's top-right, it stays on that monitor",
          inside(seen, d.visible),
          "panel \(seen) vs visible \(d.visible)")
    check("and does not spill onto the built-in display next to it",
          !seen.intersects(threeAcross[0].frame))
    // It hangs from the icon, so its top lands a little below the menu-bar line
    // — the gap the popover's pointer lives in. AppKit leaves 10pt when it does
    // this itself, measured. What matters is that it is below the line and not
    // halfway down the screen.
    check("its top edge sits just under that monitor's menu bar",
          seen.maxY <= d.visible.maxY && seen.maxY > d.visible.maxY - 16,
          "top at \(seen.maxY), menu bar at \(d.visible.maxY)")
}

func testClampArithmetic() {
    print("\nclamping")

    let builtIn = threeAcross[0].visible
    let left = threeAcross[1].visible

    // The originally reported shape: overflowing the left monitor's right edge.
    let spill = CGRect(x: -243, y: 289, width: 406, height: 420)
    check("a panel at the left monitor's top-right does overflow it",
          spill.maxX > left.maxX,
          "overflows by \(Int(spill.maxX - left.maxX))pt — this is the reported case")
    check("clamping pulls it fully back onto the left monitor",
          inside(PanelPlacement.clamp(spill, into: left), left))

    let spillRight = CGRect(x: 2900, y: 500, width: 406, height: 420)
    check("a panel overflowing the right monitor is pulled back",
          inside(PanelPlacement.clamp(spillRight, into: threeAcross[2].visible),
                 threeAcross[2].visible))

    let tall = CGRect(x: 800, y: 400, width: 406, height: 620)
    check("a tall panel is pulled fully onto the built-in display",
          inside(PanelPlacement.clamp(tall, into: builtIn), builtIn))

    let fine = CGRect(x: 100, y: 100, width: 406, height: 420)
    check("a panel that already fits is left alone",
          PanelPlacement.clamp(fine, into: builtIn) == fine)

    // The shadow is not the panel. A window frame whose transparent border
    // crosses the line, while the panel inside it does not, must not be moved —
    // that nudged a correctly placed panel 3pt down the screen on every open.
    let shadowOverTheLine = CGRect(x: 100, y: builtIn.maxY - 656 + 3,
                                   width: 406, height: 656)
    check("a window whose shadow crosses the edge but whose panel does not is left alone",
          PanelPlacement.clamp(shadowOverTheLine, into: builtIn, shadow: panelShadow)
              == shadowOverTheLine,
          "3pt of shadow over the line, 10pt of panel still clear of it")

    // Bigger than the screen: pin to the top-left rather than centring, so the
    // headline is what survives.
    let huge = CGRect(x: 500, y: -200, width: 406, height: 900)
    let pinned = PanelPlacement.clamp(huge, into: builtIn)
    check("a panel taller than the screen is pinned to the top",
          pinned.maxY == builtIn.maxY - 8,
          "the headline matters more than the buttons")
}

// MARK: - Is the app broken, or just opening?
//
// The wrong answer here accuses a working app in front of the person using it.
// It has been wrong once: ChatGPT was told it had nothing to show about a second
// before it finished updating and opened its window.

typealias Step = EmptyAppPatience.Step

func step(terminated: Bool = false,
          showsSomethingNow: Bool = false,
          personMovedOn: Bool = false,
          stillStartingUp: Bool = false,
          alreadyAsked: Bool = false,
          secondsSinceAsking: TimeInterval = 0,
          looksSoFar: Int = 1) -> Step {
    EmptyAppPatience.step(terminated: terminated,
                       showsSomethingNow: showsSomethingNow,
                       personMovedOn: personMovedOn,
                       stillStartingUp: stillStartingUp,
                       alreadyAsked: alreadyAsked,
                       secondsSinceAsking: secondsSinceAsking,
                       looksSoFar: looksSoFar)
}

func testBrokenOrJustOpening() {
    print("\nis it broken, or just opening")

    // The reported case, look by look. ChatGPT's own updater replaced it and
    // started it again; it had no window yet and had been running under a second.
    check("an app that is still starting up is never accused",
          step(stillStartingUp: true) == .keepWaiting,
          "this is the ChatGPT update case")
    check("...not even after many looks, while it is still starting",
          step(stillStartingUp: true, looksSoFar: 5) == .keepWaiting)
    check("...and the moment its window appears, nothing is said",
          step(showsSomethingNow: true, stillStartingUp: true) == .goQuiet)

    // An updater that quits the old copy leaves a terminated process behind.
    check("an app that has quit is never accused",
          step(terminated: true) == .goQuiet)
    check("a quit app is not accused even after asking and waiting",
          step(terminated: true, alreadyAsked: true, secondsSinceAsking: 99) == .goQuiet)

    check("an app the person has moved away from is left alone",
          step(personMovedOn: true, alreadyAsked: true, secondsSinceAsking: 99) == .goQuiet)

    // The real bug: an app that has been running a while, came forward, and has
    // nothing. Ask first — never announce a problem before trying to fix it.
    check("an app that is up and empty is asked for a window first",
          step() == .askForAWindow)
    check("having asked, it gets a grace period before anything is said",
          step(alreadyAsked: true, secondsSinceAsking: 1.0) == .keepWaiting)
    check("only after the asking has clearly failed is anything said",
          step(alreadyAsked: true,
               secondsSinceAsking: EmptyAppPatience.graceAfterAsking) == .speak)

    // The cap: something is wrong with the watching itself. Never guess.
    check("an app that never finishes starting is dropped quietly, not accused",
          step(stillStartingUp: true, looksSoFar: EmptyAppPatience.mostLooks) == .goQuiet,
          "we never got to ask it anything, so there is nothing honest to say")
    check("but one that was asked and stayed empty is still explained",
          step(alreadyAsked: true, looksSoFar: EmptyAppPatience.mostLooks) == .speak)

    // The panel says "I asked it to open one and it did not answer". That has to
    // be true when it is shown.
    var spokeWithoutAsking = false
    for terminated in [true, false] {
        for shows in [true, false] {
            for moved in [true, false] {
                for starting in [true, false] {
                    for looks in [0, 1, EmptyAppPatience.mostLooks] {
                        let s = step(terminated: terminated, showsSomethingNow: shows,
                                     personMovedOn: moved, stillStartingUp: starting,
                                     alreadyAsked: false, looksSoFar: looks)
                        if s == .speak { spokeWithoutAsking = true }
                    }
                }
            }
        }
    }
    check("it never says 'I asked and it did not answer' without having asked",
          !spokeWithoutAsking)

    // How long the reported case would now have had. ChatGPT's window arrived
    // about 2.7s after it came forward; the old code spoke at 1.7s.
    let patience = 0.7 + Double(EmptyAppPatience.mostLooks) * EmptyAppPatience.lookAgainEvery
    check("a starting app now gets many seconds, not one",
          patience > 10,
          "\(String(format: "%.1f", patience))s before it can be called broken")
}

// MARK: -

print("unstray core tests")
testReachability()
testWindowFiltering()
testSettings()
testSeverityOrder()
testVersionDrift()
testHeadlines()
testDiagram()
testTitleBarReach()
testUsabilityVsExistence()
testScreenSpace()
testAnchorIsChecked()
testTargetDisplay()
testPanelIsAlwaysOnItsScreen()
testPanelFollowsAVisibleIcon()
testClampArithmetic()
testBrokenOrJustOpening()

print("\n\(checks - failures)/\(checks) passed")
exit(failures == 0 ? 0 : 1)
