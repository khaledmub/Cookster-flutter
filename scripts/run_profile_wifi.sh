#!/usr/bin/env bash
# Run Cookster in Flutter profile mode over Wi-Fi ADB.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install Android platform-tools."
  exit 1
fi

adb start-server >/dev/null

if [[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
  echo "Connecting to $1 ..."
  adb connect "$1"
fi

echo "ADB devices:"
adb devices -l
echo ""
echo "Flutter devices:"
flutter devices

DEVICE_ID="$(flutter devices 2>/dev/null | grep -E '• android|• CPH|mobile' | head -1 | awk -F'•' '{print $2}' | xargs || true)"
if [[ -z "${DEVICE_ID}" ]]; then
  echo ""
  echo "No Android device found."
  echo "On your phone (CPH2203): Settings → Developer options → Wireless debugging → ON"
  echo "  1. Tap 'Pair device with pairing code'"
  echo "  2. Run:  adb pair <ip>:<pairing-port>   (enter the 6-digit code)"
  echo "  3. Run:  adb connect <ip>:<debug-port>"
  echo "  4. Re-run:  ./scripts/run_profile_wifi.sh <ip>:<debug-port>"
  echo ""
  echo "Or USB once:  adb tcpip 5555 && adb connect <phone-ip>:5555"
  exit 1
fi

echo ""
echo "Launching profile build on: $DEVICE_ID"
exec flutter run --profile -d "$DEVICE_ID"
