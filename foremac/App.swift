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
struct ForemacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hotKeyRef: EventHotKeyRef?
    private var model = VerdictModel()
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

        Lifecycle.enableLaunchAtLoginOnce()

        // A macOS update is exactly when settings drift, so look straight away
        // and be ready to say that the update is what changed things.
        model.blameUpdate = Lifecycle.didOSUpdateSinceLastRun()
        model.recheck()

        // If the update broke something, do not wait to be asked — open and
        // say so. This is the one time the app is allowed to interrupt.
        if model.blameUpdate, case .somethingWrong = model.verdict {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.showPanel(sticky: true)
            }
        }

        RepairLog.write(event: "launched", detail: [
            "os": Lifecycle.currentOSVersion,
            "afterUpdate": model.blameUpdate,
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
                            needsAttention ? "foremac — found something" : "foremac — all clear")
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
            ? "foremac found something — click to see"
            : "foremac — everything is where it should be"
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
    }

    @objc private func togglePopover() {
        guard let b = statusItem.button else { return }
        if popover.isShown {
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
            popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
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

        let id = EventHotKeyID(signature: OSType(0x464D4143), id: 1)  // 'FMAC'
        RegisterEventHotKey(UInt32(kVK_ANSI_R),
                            UInt32(optionKey | cmdKey),
                            id, GetApplicationEventTarget(), 0, &hotKeyRef)
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
    private func showPanel(sticky: Bool = false) {
        guard let b = statusItem.button, !popover.isShown else { return }
        model.recheck()
        popover.behavior = sticky ? .applicationDefined : .transient
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
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

    /// Set once at launch when macOS has changed since we last ran, so the
    /// first check after an update can name the culprit.
    var blameUpdate = false

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

        // If macOS changed under us and something is now wrong, say so. "Your
        // Mac updated itself and changed this" is the answer to the question
        // they are really asking, which is why this started happening today.
        if blameUpdate, !findings.isEmpty {
            for i in findings.indices where findings[i].kind != .strandedWindows {
                findings[i].blamesOSUpdate = true
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
