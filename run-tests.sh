#!/bin/bash
# Runs the core logic tests. No framework, no Xcode project, ~1 second.
set -e
OUT=$(mktemp -d)
# The real placement code is compiled in, not copied. A test that re-implements
# what it is testing cannot fail when the shipped code breaks, and this file
# spent two releases doing exactly that.
#
# Copied in as main.swift because once more than one file is compiled, Swift only
# allows top-level statements in a file with that name.
cp tests/CoreTests.swift "$OUT/main.swift"
swiftc -o "$OUT/tests" \
    unstray/Core/PanelPlacement.swift \
    unstray/Core/ScreenSpace.swift \
    unstray/Core/EmptyAppPatience.swift \
    "$OUT/main.swift" 2>&1 | grep -E "error" && exit 1
"$OUT/tests"
