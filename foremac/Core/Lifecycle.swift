import Foundation
import ServiceManagement

/// Starting with the Mac, and noticing when macOS has changed underneath us.
enum Lifecycle {

    // MARK: - Start with the Mac

    /// An app that only helps when it is running should run without being asked.
    static var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setLaunchAtLogin(_ on: Bool) -> Bool {
        do {
            if on {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            RepairLog.write(event: "launch_at_login_failed",
                            detail: ["wanted": on, "error": "\(error)"])
            return false
        }
    }

    /// Turns itself on the first time only. If the person later switches it off,
    /// that decision sticks — an app that keeps re-enabling itself is spyware
    /// behaviour, however well meant.
    static func enableLaunchAtLoginOnce() {
        let key = "fm.didOfferLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        setLaunchAtLogin(true)
        RepairLog.write(event: "launch_at_login_enabled")
    }

    // MARK: - Noticing a macOS update
    //
    // This is the whole reason the app exists. `spans-displays` turned itself
    // off during a Tahoe update, blacked out two screens, and stranded five
    // things off the edge of everything. Nobody touched it, and macOS never
    // said a word. So: remember the version we last saw, and when it changes,
    // look again — that is exactly the moment settings drift.

    private static let versionKey = "fm.lastSeenOSVersion"

    static var currentOSVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// The version we saw last time, or nil on a first run.
    static var lastSeenOSVersion: String? {
        UserDefaults.standard.string(forKey: versionKey)
    }

    /// True when macOS has changed since we last looked. Records the new
    /// version as a side effect, so this reports true exactly once per update.
    static func didOSUpdateSinceLastRun() -> Bool {
        let now = currentOSVersion
        defer { UserDefaults.standard.set(now, forKey: versionKey) }
        guard let last = lastSeenOSVersion else { return false }  // first run is not an update
        guard last != now else { return false }
        RepairLog.write(event: "os_updated", detail: ["from": last, "to": now])
        return true
    }
}
