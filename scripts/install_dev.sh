#!/usr/bin/env bash
# Rebuild and reinstall the locally signed Release app to /Applications.
# Uses the same Apple Development identity from Signing.xcconfig so macOS
# keeps Screen Recording and Accessibility grants across fast UI iterations.
# Do not use this over a notarized production install.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/build/audit-release/Build/Products/Release/PeekOCR.app"
APP_DST="/Applications/PeekOCR.app"

cd "$ROOT"
make release

if [[ ! -d "$APP_SRC" ]]; then
  echo "install-dev: expected app bundle at $APP_SRC" >&2
  exit 1
fi

SIGNING_DETAILS="$(codesign -dvvv "$APP_SRC" 2>&1 || true)"
if ! grep -q "Authority=Apple Development" <<<"$SIGNING_DETAILS"; then
  echo "install-dev: Release app is not signed with Apple Development." >&2
  echo "install-dev: copy Signing.xcconfig.example to Signing.xcconfig and set DEVELOPMENT_TEAM." >&2
  exit 65
fi
if ! grep -q "^TeamIdentifier=" <<<"$SIGNING_DETAILS"; then
  echo "install-dev: Release app has no TeamIdentifier; refusing to replace a TCC-granted install." >&2
  exit 65
fi

osascript -e 'tell application "PeekOCR" to quit' 2>/dev/null || true
sleep 1
if pgrep -x PeekOCR >/dev/null 2>&1; then
  killall PeekOCR 2>/dev/null || true
  sleep 1
fi

ditto "$APP_SRC" "$APP_DST"
open "$APP_DST"

CDHASH="$(codesign -dvvv "$APP_DST" 2>&1 | sed -n 's/^CDHash=//p' | head -1)"
echo "install-dev: installed CDHash=${CDHASH:-unknown} to $APP_DST"
