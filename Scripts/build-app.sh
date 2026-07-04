#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
APP="$ROOT/build/Spoiler Delay.app"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/SpoilerDelay" "$CONTENTS/MacOS/SpoilerDelay"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi

IDENTITY="${CODE_SIGN_IDENTITY:--}"
if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --options runtime --timestamp=none \
    --entitlements "$ROOT/Resources/SpoilerDelay.entitlements" \
    --sign "$IDENTITY" "$APP"
else
  codesign --force --options runtime --timestamp \
    --entitlements "$ROOT/Resources/SpoilerDelay.entitlements" \
    --sign "$IDENTITY" "$APP"
fi

echo "$APP"
