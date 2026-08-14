#!/bin/bash
# Runs the core logic tests. No framework, no Xcode project, ~1 second.
set -e
OUT=$(mktemp -d)
# The real placement code is compiled in, not copied. A test that re-implements
# what it is testing cannot fail when the shipped code breaks, and this file
# spent two releases doing exactly that.
#
# Only the modules that decide something without touching the machine belong
# here. Every decision this app makes is deliberately kept in one of these, so
# that this list stays short: pulling in the window-moving or accessibility code
# to reach one function would make the tests slower, and would put code that can
# move a person's windows one careless line away from running in a test.
#
# Copied in as main.swift because once more than one file is compiled, Swift only
# allows top-level statements in a file with that name.
cp tests/CoreTests.swift "$OUT/main.swift"
swiftc -o "$OUT/tests" \
    unstray/Core/Finding.swift \
    unstray/Core/PanelPlacement.swift \
    unstray/Core/ScreenSpace.swift \
    unstray/Core/WindowUse.swift \
    unstray/Core/WindowlessByDesign.swift \
    unstray/Core/EmptyAppPatience.swift \
    unstray/Core/ProblemFate.swift \
    "$OUT/main.swift" 2>&1 | grep -E "error" && exit 1
"$OUT/tests"
