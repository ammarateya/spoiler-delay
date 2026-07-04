#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
: "${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE to a notarytool keychain profile}"

"$ROOT/Scripts/build-app.sh"
APP="$ROOT/build/Spoiler Delay.app"
SUBMISSION="$ROOT/build/SpoilerDelay-notarization.zip"
FINAL="$ROOT/build/SpoilerDelay-macOS.zip"

ditto -c -k --keepParent "$APP" "$SUBMISSION"
xcrun notarytool submit "$SUBMISSION" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$APP"
rm -f "$SUBMISSION" "$FINAL"
ditto -c -k --keepParent "$APP" "$FINAL"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP"
echo "$FINAL"
