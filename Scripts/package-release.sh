#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
"$ROOT/Scripts/build-app.sh"
cd "$ROOT/build"
ditto -c -k --keepParent "Spoiler Delay.app" "SpoilerDelay-macOS.zip"
echo "$ROOT/build/SpoilerDelay-macOS.zip"
