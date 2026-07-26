#!/bin/bash
# Runs the core logic tests. No framework, no Xcode project, ~1 second.
set -e
OUT=$(mktemp -d)
swiftc -o "$OUT/tests" tests/CoreTests.swift 2>&1 | grep -E "error" && exit 1
"$OUT/tests"
