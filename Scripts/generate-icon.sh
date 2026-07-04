#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SVG="${1:-$ROOT/Resources/AppIcon.svg}"
ICONSET="$ROOT/Resources/AppIcon.iconset"
MASTER="$ICONSET/icon_512x512@2x.png"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -s format png "$SVG" --out "$MASTER" >/dev/null

for points in 16 32 128 256 512; do
  sips -z "$points" "$points" "$MASTER" --out "$ICONSET/icon_${points}x${points}.png" >/dev/null
  pixels=$((points * 2))
  if [[ "$pixels" -ne 1024 ]]; then
    sips -z "$pixels" "$pixels" "$MASTER" --out "$ICONSET/icon_${points}x${points}@2x.png" >/dev/null
  fi
done

iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
echo "$ROOT/Resources/AppIcon.icns"
