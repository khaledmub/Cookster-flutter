#!/usr/bin/env bash
# Run Cookster in Flutter profile mode on a USB-connected Android device (production API).
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install Android platform-tools."
  exit 1
fi

adb start-server >/dev/null

echo "ADB devices:"
adb devices -l
echo ""
echo "Flutter devices:"
flutter devices

DEVICE_ID="$(flutter devices 2>/dev/null | grep -E '• android|• CPH|mobile' | head -1 | awk -F'•' '{print $2}' | xargs || true)"
if [[ -z "${DEVICE_ID}" ]]; then
  echo ""
  echo "No Android device found. Connect your phone via USB and enable USB debugging."
  exit 1
fi

echo ""
echo "Launching profile build on: $DEVICE_ID (API: https://cookster.org/api/)"
exec flutter run --profile -d "$DEVICE_ID"
