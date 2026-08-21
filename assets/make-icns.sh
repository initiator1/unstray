#!/bin/bash
# Builds assets/unstray.icns from assets/unstray-1024.png.
#
# The master PNG is generated with gpt-image-2 via Codex's native image_gen.
# Never hand-rolled SVG or CSS art. See CLAUDE.md.
#
# There is no Xcode asset catalogue in this repo, so every size is made here.
# macOS picks 32pt for the Dock at 1x and the Finder list view, which is where
# a busy icon falls apart — check that size before shipping.
set -euo pipefail
cd "$(dirname "$0")"

SRC=unstray-1024.png
SET=unstray.iconset

[ -f "$SRC" ] || { echo "error: $SRC is missing" >&2; exit 1; }

rm -rf "$SET" && mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -s format png -z $s $s        "$SRC" --out "$SET/icon_${s}x${s}.png"    >/dev/null
  sips -s format png -z $((s*2)) $((s*2)) "$SRC" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done

iconutil -c icns "$SET" -o unstray.icns
echo "built: assets/unstray.icns"
