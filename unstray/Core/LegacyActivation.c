#include "LegacyActivation.h"
#include <ApplicationServices/ApplicationServices.h>

// Silence the deprecation warnings: reaching these symbols is the entire point
// of this file, and the reasoning is documented in the header.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

bool us_bring_app_to_front(pid_t pid) {
    ProcessSerialNumber psn = {0, 0};
    if (GetProcessForPID(pid, &psn) != noErr) {
        return false;
    }
    // options = 0 means "bring all of this app's windows forward", which is the
    // behaviour the modern API lost in macOS 10.15.
    return SetFrontProcessWithOptions(&psn, 0) == noErr;
}

#pragma clang diagnostic pop
