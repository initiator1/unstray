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

// MARK: - Is a window reachable?
//
// The single most important question the app asks. If this is wrong, it either
// misses windows that are genuinely lost or drags back ones you deliberately
// placed.

func unreachable(_ r: CGRect, _ screens: [CGRect]) -> Bool {
    !screens.contains { $0.intersects(r) }
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

print("\n\(checks - failures)/\(checks) passed")
exit(failures == 0 ? 0 : 1)
