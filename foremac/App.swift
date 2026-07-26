import SwiftUI
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

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon, no menu bar menus

        buildStatusItem()
        buildPopover()
        registerHotKey()
        observeSystemEvents()

        model.recheck()
        RepairLog.write(event: "launched")
    }

    // MARK: - The picture in the bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = statusItem.button {
            b.image = NSImage(
                systemSymbolName: "rectangle.on.rectangle",
                accessibilityDescription: "foremac"
            )
            b.image?.isTemplate = true
            b.action = #selector(togglePopover)
            b.target = self
        }
    }

    private func buildPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let host = NSHostingController(
            rootView: VerdictHost(model: model, onQuit: { NSApp.terminate(nil) })
        )
        popover.contentViewController = host
    }

    @objc private func togglePopover() {
        guard let b = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.recheck()
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
            showPanel()
            return
        }
        // Whatever the person was trying to reach is the app that was in front
        // before we became frontmost.
        let didSomething = WindowRescue.gatherFrontmostApp()
        RepairLog.write(event: "hotkey", detail: ["movedSomething": didSomething])
        if !didSomething { showPanel() }
    }

    private func showPanel() {
        guard let b = statusItem.button, !popover.isShown else { return }
        model.recheck()
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
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

    func recheck(reason: String? = nil) {
        // Without permission we cannot move anything, so reporting problems we
        // are unable to fix would be a UI that promises what it cannot deliver.
        guard WindowRescue.hasPermission else {
            verdict = .needsPermission
            return
        }
        awaitingPermission = false
        stopPolling()

        let findings = SettingsCheck.runAll() + [WindowScan.check()].compactMap { $0 }

        if findings.isEmpty {
            verdict = .allWell(lastCheckedDescription: "Checked just now")
        } else {
            let sorted = findings.sorted { $0.severity < $1.severity }
            verdict = .somethingWrong(primary: sorted[0], alsoFound: Array(sorted.dropFirst()))
            RepairLog.found(sorted)
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
    let onQuit: () -> Void

    var body: some View {
        VerdictView(
            verdict: model.verdict,
            awaitingPermission: model.awaitingPermission,
            onRepair: { model.repair($0) },
            onRecheck: { model.recheck(reason: "asked") },
            onGrantPermission: { model.requestPermission() },
            onOpenPrivacySettings: { model.openPrivacySettings() },
            onQuit: onQuit
        )
    }
}
