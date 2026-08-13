import SwiftUI
import Combine
import Carbon.HIToolbox

/// The app itself: a small picture in the bar at the top of the screen that
/// stays out of the way until it is needed.
///
/// It does not sit and watch. Watching would mean polling, guessing, and moving
/// things around while a person is trying to work — and it cannot reliably be
/// done anyway, because macOS gives no way to tell "the person clicked this
/// app's picture" apart from any other way of switching apps.
///
/// So it checks at the moments that actually matter:
///   - when you open it
///   - when you press the key combination
///   - when a screen is plugged in or unplugged
///   - when the Mac wakes up
///   - after a macOS update, which is what silently broke things last time
@main
struct UnstrayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hotKeyRef: EventHotKeyRef?

    /// The key combination we actually got, for showing in the UI. nil when
    /// every candidate was already taken by another app.
    private(set) var hotKeyLabel: String? = "\u{2325}\u{2318}R"
    private var model = VerdictModel()
    private let emptyAppWatch = EmptyAppWatch()
    private var frameObservers: [NSObjectProtocol] = []
    private var isClamping = false

    /// Something for the panel to hang from when the menu-bar icon is hidden.
    /// Created once, on demand. See panelAnchor().
    private var standInAnchor: NSWindow?
    private var verdictObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon, no menu bar menus

        buildStatusItem()
        buildPopover()
        registerHotKey()
        observeSystemEvents()

        // Whenever the answer changes, the picture in the bar changes with it.
        verdictObserver = model.$verdict
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }

        // Keep note of which app the person is actually using, so the rescue
        // key knows what to go and find.
        ActivityWatch.shared.start()

        // Clicking an app IS the request to see it. When one comes forward with
        // nothing to show, fix it without asking; speak only if that fails.
        emptyAppWatch.onUnfixable = { [weak self] appName, problem in
            self?.model.showUnusable(appName: appName, problem: problem)
            self?.showPanel(sticky: true, keepVerdict: true)
        }
        emptyAppWatch.start()

        Lifecycle.enableLaunchAtLoginOnce()

        // An OS update is a sensible moment to look, so check straight away.
        model.followsOSUpdate = Lifecycle.didOSUpdateSinceLastRun()
        model.recheck()

        // Only interrupt for something that is actually wrong NOW.
        //
        // Opening by itself is the rudest thing this app can do, so the bar has
        // to be high. A `willBiteLater` finding does not clear it: the
        // single-screen version of the black-screens panel literally says
        // "nothing is wrong right now", and interrupting someone to tell them
        // nothing is wrong is worse than staying quiet. Those wait until they
        // open the app themselves, and the menu bar icon carries the hint.
        if model.followsOSUpdate, model.hasUrgentProblem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.showPanel(sticky: true)
            }
        }

        RepairLog.write(event: "launched", detail: [
            "os": Lifecycle.currentOSVersion,
            "afterUpdate": model.followsOSUpdate,
            "launchesAtLogin": Lifecycle.launchesAtLogin
        ])
    }

    // MARK: - The picture in the bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = statusItem.button {
            b.action = #selector(togglePopover)
            b.target = self
        }
        updateStatusIcon()
    }

    /// The picture in the bar says what we know, without being opened.
    ///
    /// Quiet by default: a plain outline that reads as "nothing to do", drawn as
    /// a template so it follows light and dark menu bars. When something needs
    /// attention it fills in and takes on the same amber used inside the app, so
    /// the two are recognisably one thing. It never flashes, never animates, and
    /// never uses red — a menu bar that shouts is a menu bar people remove.
    fileprivate func updateStatusIcon() {
        guard let b = statusItem.button else { return }
        let needsAttention: Bool
        switch model.verdict {
        case .allWell:                         needsAttention = false
        case .needsPermission, .somethingWrong: needsAttention = true
        }

        let name = needsAttention ? "rectangle.on.rectangle.fill" : "rectangle.on.rectangle"
        let img = NSImage(systemSymbolName: name, accessibilityDescription:
                            needsAttention ? "unstray — found something" : "unstray — all clear")
        if needsAttention {
            // Amber, so it matches the panel it opens. Not a template image,
            // because the colour is the message.
            img?.isTemplate = false
            b.image = img?.tinted(with: NSColor(red: 0.933, green: 0.702, blue: 0.400, alpha: 1))
        } else {
            img?.isTemplate = true
            b.image = img
        }
        b.toolTip = needsAttention
            ? "unstray found something — click to see"
            : "unstray — everything is where it should be"
    }

    private func buildPopover() {
        popover = NSPopover()
        // Closes when you click elsewhere — right for a panel you opened on
        // purpose. When the app opens itself to tell you something, this is
        // switched to .applicationDefined so the message cannot vanish before
        // it has been read. See showPanel(sticky:).
        popover.behavior = .transient
        popover.animates = true
        let host = NSHostingController(
            rootView: VerdictHost(
                model: model,
                onDismiss: { [weak self] in
                    self?.popover.behavior = .transient
                    self?.popover.performClose(nil)
                },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        popover.contentViewController = host

        // A transient panel closes by itself when you click elsewhere, and that
        // path goes through none of the buttons — so tidy up here or the frame
        // watchers outlive the window they were watching.
        NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification, object: popover, queue: .main
        ) { [weak self] _ in self?.stopWatchingPanelFrame() }
    }

    /// Escape always closes the panel, in every state. A keyboard way out is
    /// the backstop for any sticky panel — buttons can be missed, Escape cannot.
    fileprivate func closePanel() {
        guard popover.isShown else { return }
        stopWatchingPanelFrame()
        popover.behavior = .transient
        popover.performClose(nil)
    }

    @objc private func togglePopover() {
        guard statusItem.button != nil else { return }
        if popover.isShown {
            stopWatchingPanelFrame()
            popover.behavior = .transient
            popover.performClose(nil)
        } else {
            model.recheck()
            // A panel showing a problem must not vanish when the person clicks
            // the very app they are trying to rescue. Only the all-clear panel
            // is safe to dismiss by clicking away — losing that costs nothing.
            let hasProblem: Bool
            if case .allWell = model.verdict { hasProblem = false } else { hasProblem = true }
            popover.behavior = hasProblem ? .applicationDefined : .transient
            guard let (view, rect) = panelAnchor() else { return }
            popover.show(relativeTo: rect, of: view, preferredEdge: .minY)
            clampPanel()
            watchPanelFrame()
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - The key combination
    //
    // ⌥⌘R — "rescue". Pressing it makes this app frontmost, which is exactly the
    // state macOS requires before one app is allowed to bring another forward.
    // That is why a key press works where a background watcher cannot.

    private func registerHotKey() {
        var handler: EventHandlerRef?
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            guard let ctx else { return noErr }
            Unmanaged<AppDelegate>.fromOpaque(ctx)
                .takeUnretainedValue()
                .rescuePressed()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)

        // Try ⌥⌘R first, then a fallback, because plenty of window tools already
        // own ⌥⌘R. If registration fails and we ignore it, the rescue key does
        // nothing for ever and never says why — which is the exact silent
        // failure this app exists to correct. So we check, and we report.
        let candidates: [(UInt32, UInt32, String)] = [
            (UInt32(kVK_ANSI_R), UInt32(optionKey | cmdKey),            "\u{2325}\u{2318}R"),
            (UInt32(kVK_ANSI_R), UInt32(optionKey | cmdKey | shiftKey), "\u{2325}\u{21E7}\u{2318}R"),
            (UInt32(kVK_ANSI_W), UInt32(optionKey | cmdKey | shiftKey), "\u{2325}\u{21E7}\u{2318}W")
        ]

        for (i, c) in candidates.enumerated() {
            let id = EventHotKeyID(signature: OSType(0x464D4143), id: UInt32(i + 1))
            let err = RegisterEventHotKey(c.0, c.1, id,
                                          GetApplicationEventTarget(), 0, &hotKeyRef)
            if err == noErr, hotKeyRef != nil {
                hotKeyLabel = c.2
                if i > 0 {
                    RepairLog.write(event: "hotkey_fallback",
                                    detail: ["using": c.2, "reason": "preferred key taken"])
                }
                return
            }
        }

        // Nothing worked. Say so in the log and remember it, so the app can be
        // honest about it rather than pretending it has a rescue key.
        hotKeyLabel = nil
        RepairLog.write(event: "hotkey_unavailable",
                        detail: ["reason": "every candidate combination is taken"])
    }

    fileprivate func rescuePressed() {
        // Never fail quietly. Silently doing nothing is the exact bug this app
        // exists to fix, so if we cannot help we say so on screen.
        guard WindowRescue.hasPermission else {
            RepairLog.write(event: "hotkey", detail: ["blocked": "no permission"])
            showPanel(sticky: true)
            return
        }
        // Whatever the person was trying to reach is the app that was in front
        // before we became frontmost.
        let didSomething = WindowRescue.gatherFrontmostApp()
        RepairLog.write(event: "hotkey", detail: ["movedSomething": didSomething])
        if !didSomething { showPanel(sticky: true) }
    }

    /// Opens the panel.
    ///
    /// `sticky` is for the times the app speaks first — after a macOS update,
    /// or when the rescue key could not help. Those messages must survive the
    /// person clicking on whatever they were reaching for; a notice that
    /// vanishes before it is read is the same silent failure this app exists
    /// to correct. Sticky panels close only via their own buttons.
    /// Keeps the panel fully on screen, and keeps it there.
    ///
    /// NSPopover anchors to its button, does not clamp to the screen, and actively
    /// repositions itself to track that anchor. With the menu-bar icon near a
    /// corner the panel runs off the edge and the text is cut off mid-sentence —
    /// a bad look for an app about windows ending up where you cannot read them.
    ///
    /// Three things went wrong in the first attempt at this, and all three are
    /// why it only misbehaved "occasionally":
    ///   - it clamped immediately after `show()`, while the popover was still
    ///     animating, so it read a frame that was not final;
    ///   - it only clamped horizontally, and a problem panel can be 600pt tall;
    ///   - it clamped once, so any later resize (the panel height is driven by
    ///     its content) or any repositioning by AppKit undid it.
    /// So this now runs after the animation AND on every move or resize while
    /// the panel is open.
    private func clampPanel() {
        guard !isClamping,
              let win = popover.contentViewController?.view.window
        else { return }

        let displays = PanelPlacement.displays()
        guard let i = PanelPlacement.targetDisplay(anchor: statusItem.button?.window?.frame,
                                                   pointer: NSEvent.mouseLocation,
                                                   displays: displays)
        else { return }

        let target = PanelPlacement.clamp(win.frame,
                                          into: displays[i].visible,
                                          shadow: panelShadowInset(win))
        guard target.origin != win.frame.origin else { return }

        isClamping = true
        win.setFrame(target, display: true)
        isClamping = false
    }

    /// The transparent border NSPopover draws around the panel — 13pt a side on
    /// this Mac. Asked for rather than assumed, because it is AppKit's number and
    /// AppKit is free to change it. Treating it as part of the panel is what made
    /// an earlier version shove a correctly placed panel 3pt down the screen every
    /// time it opened.
    private func panelShadowInset(_ win: NSWindow) -> CGFloat {
        guard let content = popover.contentViewController?.view else { return 0 }
        let onScreen = win.convertToScreen(content.convert(content.bounds, to: nil))
        return max(0, onScreen.minX - win.frame.minX)
    }

    /// What the panel hangs from.
    ///
    /// Normally the menu-bar icon. But a menu-bar manager, or macOS running out
    /// of room up there, hides an icon by parking its window off the left edge of
    /// every screen — measured at x ≈ -10094 on this Mac, drifting a little
    /// between runs — while still reporting it as visible. Hanging the panel off
    /// that point makes AppKit drop the panel
    /// against the left edge of the leftmost monitor, which is how it ends up on a
    /// screen the person is not even looking at.
    ///
    /// So when the icon is not really anywhere, we pick the spot ourselves: under
    /// the menu bar of the screen the pointer is on, where the panel would have
    /// appeared if the icon had been visible.
    private func panelAnchor() -> (NSView, NSRect)? {
        let displays = PanelPlacement.displays()
        let iconFrame = statusItem.button?.window?.frame

        if PanelPlacement.isUsableAnchor(iconFrame, displays: displays),
           let b = statusItem.button {
            hideStandInAnchor()
            return (b, b.bounds)
        }

        // No screens at all, or nothing to hang from: fall back to the icon
        // rather than quietly declining to open. A panel that does not appear is
        // the exact silent failure this app exists to correct.
        let stand = standInAnchorWindow()
        guard let i = PanelPlacement.targetDisplay(anchor: iconFrame,
                                                   pointer: NSEvent.mouseLocation,
                                                   displays: displays),
              let cv = stand.contentView
        else {
            RepairLog.write(event: "panel_anchor_fallback",
                            detail: ["reason": "no display to place the panel on"])
            return statusItem.button.map { ($0, $0.bounds) }
        }

        stand.setFrame(PanelPlacement.fallbackAnchor(on: displays[i]), display: false)
        stand.orderFront(nil)
        return (cv, cv.bounds)
    }

    /// A one-point invisible window, used only as something for the panel to hang
    /// from when the menu-bar icon is hidden. Too small and too high a layer to be
    /// mistaken for a real window by anything, including this app's own scan.
    private func standInAnchorWindow() -> NSWindow {
        if let w = standInAnchor { return w }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        standInAnchor = w
        return w
    }

    private func hideStandInAnchor() {
        standInAnchor?.orderOut(nil)
    }

    /// Re-clamps for as long as the panel is open, since it can be moved or
    /// resized after it appears.
    private func watchPanelFrame() {
        guard let win = popover.contentViewController?.view.window else { return }
        for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
            let token = NotificationCenter.default.addObserver(
                forName: name, object: win, queue: .main
            ) { [weak self] _ in self?.clampPanel() }
            frameObservers.append(token)
        }
        // One more pass after the show animation finishes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.clampPanel()
        }
    }

    private func stopWatchingPanelFrame() {
        frameObservers.forEach { NotificationCenter.default.removeObserver($0) }
        frameObservers.removeAll()
        hideStandInAnchor()
    }

    /// `keepVerdict` is for the times we already know what to say — rechecking
    /// would scan for settings and stray windows and overwrite it with a cheerful
    /// "all clear", which is how this panel first shipped saying the opposite of
    /// what it had just detected.
    private func showPanel(sticky: Bool = false, keepVerdict: Bool = false) {
        guard statusItem.button != nil, !popover.isShown else { return }
        if !keepVerdict { model.recheck() }
        popover.behavior = sticky ? .applicationDefined : .transient
        guard let (view, rect) = panelAnchor() else { return }
        popover.show(relativeTo: rect, of: view, preferredEdge: .minY)
        clampPanel()
        watchPanelFrame()
        if sticky {
            // Bring ourselves forward so the panel is not buried behind the
            // window the person clicks next.
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - When to look again

    private func observeSystemEvents() {
        let nc = NSWorkspace.shared.notificationCenter
        // Waking up is when stranded things appear.
        nc.addObserver(forName: NSWorkspace.didWakeNotification,
                       object: nil, queue: .main) { [weak self] _ in
            self?.model.recheck()
        }
        // Plugging or unplugging a screen is the single biggest cause of things
        // being left somewhere unreachable.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Give macOS a moment to finish rearranging before judging it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.model.recheck(reason: "screens changed")
            }
        }
    }
}

/// Keeps the current answer, and knows how to work it out again.
final class VerdictModel: ObservableObject {
    @Published var verdict: Verdict = .allWell(lastCheckedDescription: "Checked just now")

    /// True between asking for permission and being given it, so the panel can
    /// say "your Mac is asking you now" instead of repeating the request.
    @Published var awaitingPermission = false

    private var permissionPoll: Timer?

    /// Set once at launch when macOS has changed version since we last ran.
    /// Timing only — see Finding.followsOSUpdate.
    var followsOSUpdate = false

    /// True only when something is broken right now. Anything merely waiting to
    /// bite does not earn an interruption.
    var hasUrgentProblem: Bool {
        guard case .somethingWrong(let primary, _) = verdict else { return false }
        return primary.severity == .nowBroken
    }

    func recheck(reason: String? = nil) {
        let permitted = WindowRescue.hasPermission
        if permitted {
            awaitingPermission = false
            stopPolling()
        }

        // Settings problems need no permission to find OR to fix — only moving
        // things does. So always check them. Someone who said "not yet" must
        // still be told their Mac blacked out their screens; going quiet would
        // repeat the exact failure this app exists to correct.
        var findings = SettingsCheck.runAll()
        if permitted, let stranded = WindowScan.check() {
            findings.append(stranded)
        }
        if permitted, let offEdge = WindowScan.checkOffTheEdge() {
            findings.append(offEdge)
        }

        // Note that an update happened, so the panel can mention the timing.
        // Timing only — we cannot know the update caused anything, and claiming
        // it did would be making something up.
        if followsOSUpdate, !findings.isEmpty {
            for i in findings.indices
            where findings[i].kind != .strandedWindows
                && findings[i].kind != .windowOffTheEdge {
                findings[i].followsOSUpdate = true
            }
        }

        if !findings.isEmpty {
            // A problem we can fix outranks asking for permission — fixing the
            // settings needs no permission, so get on with it.
            let sorted = findings.sorted { $0.severity < $1.severity }
            verdict = .somethingWrong(primary: sorted[0], alsoFound: Array(sorted.dropFirst()))
            RepairLog.found(sorted)
        } else if !permitted {
            // Nothing wrong that we can see — but without permission we cannot
            // see everything, and could not rescue anything. Say so honestly
            // rather than claiming an all-clear we have not earned.
            verdict = .needsPermission
        } else {
            verdict = .allWell(lastCheckedDescription: "Checked just now")
        }
        if let reason { RepairLog.write(event: "rechecked", detail: ["reason": reason]) }
    }

    /// Shows whatever we could not fix about the app you just switched to.
    func showUnusable(appName: String, problem: Usability.Problem) {
        verdict = .somethingWrong(
            primary: WindowScan.unusable(appName: appName, problem: problem),
            alsoFound: []
        )
    }

    func repair(_ f: Finding) {
        let ok = f.repair()
        RepairLog.repaired(f, success: ok)
        recheck()
    }

    // MARK: - Permission

    /// Lets macOS ask its own question, then watches for the answer.
    ///
    /// macOS never tells an app that it has been trusted, so the only way to
    /// notice is to keep looking. This stops as soon as permission arrives.
    func requestPermission() {
        awaitingPermission = true
        RepairLog.write(event: "permission_requested")
        WindowRescue.requestPermission()
        startPolling()
    }

    private func startPolling() {
        stopPolling()
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if WindowRescue.hasPermission {
                RepairLog.write(event: "permission_granted")
                self.recheck(reason: "permission granted")
            }
        }
    }

    private func stopPolling() {
        permissionPoll?.invalidate()
        permissionPoll = nil
    }

    /// Opens the exact page in System Settings, so nobody has to hunt for it.
    func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

/// Bridges the model into the view.
private struct VerdictHost: View {
    @ObservedObject var model: VerdictModel
    let onDismiss: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VerdictView(
            verdict: model.verdict,
            awaitingPermission: model.awaitingPermission,
            onRepair: { model.repair($0) },
            onRecheck: { model.recheck(reason: "asked") },
            onGrantPermission: { model.requestPermission() },
            onOpenPrivacySettings: { model.openPrivacySettings() },
            onDismiss: onDismiss,
            onQuit: onQuit
        )
    }
}
