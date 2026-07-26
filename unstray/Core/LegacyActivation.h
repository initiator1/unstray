#ifndef LegacyActivation_h
#define LegacyActivation_h

#include <sys/types.h>
#include <stdbool.h>

/// Brings an app to the front, including every one of its windows.
///
/// This exists because Swift cannot reach the only call that reliably does this.
///
/// The modern replacement (`NSRunningApplication.activate`) was changed in
/// macOS 14 to a cooperative model: the app currently in front must agree to
/// yield. A menu-bar app is never in front, so its requests are silently
/// ignored — Apple has acknowledged this (FB21087054) and has not fixed it.
/// The `.activateAllWindows` option separately has not worked since macOS 10.15
/// per Apple's own engineers (FB11974786).
///
/// `SetFrontProcessWithOptions` still does both correctly. It is deprecated but
/// NOT private — no SIP disabling, no boot arguments, no scripting additions —
/// so it should keep working across OS updates. Swift refuses to import
/// pre-10.9 Carbon symbols at all, hence this shim.
///
/// Returns true if the app was brought forward.
bool us_bring_app_to_front(pid_t pid);

#endif /* LegacyActivation_h */
