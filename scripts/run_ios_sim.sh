#!/usr/bin/env bash
# Run Cookster in Flutter debug mode on the iOS Simulator (profile/release are not supported on simulators).
# Uninstalls any previous Cookster build on the target simulator for a clean install each run.
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="${HOME}/.gem/ruby/2.6.0/bin:${PATH}"

BUNDLE_ID="com.cookster.cooksterapp"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found. Install Flutter and ensure it is on your PATH."
  exit 1
fi

PREFERRED_DEVICE="${1:-iPhone 17 Pro}"

pick_ios_simulator() {
  flutter devices 2>/dev/null | awk -F'•' '/ios.*simulator/ { gsub(/^ +| +$/, "", $2); print $2; exit }'
}

resolve_sim_udid() {
  local name="$1"
  xcrun simctl list devices 2>/dev/null | grep "$name (" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'
}

boot_simulator() {
  local name="$1"
  local udid
  udid="$(resolve_sim_udid "$name")"
  if [[ -n "$udid" ]]; then
    echo "Booting simulator: $name ($udid)"
    xcrun simctl boot "$udid" 2>/dev/null || true
    open -a Simulator --args -CurrentDeviceUDID "$udid" 2>/dev/null || open -a Simulator
  else
    open -a Simulator
  fi
}

boot_simulator "$PREFERRED_DEVICE"

echo "Waiting for iOS Simulator..."
DEVICE_ID=""
for _ in $(seq 1 45); do
  if flutter devices 2>/dev/null | grep -Fq "$PREFERRED_DEVICE"; then
    DEVICE_ID="$PREFERRED_DEVICE"
    break
  fi
  sleep 2
done

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(pick_ios_simulator)"
  if [[ -n "$DEVICE_ID" ]]; then
    echo "Note: '$PREFERRED_DEVICE' not available; using '$DEVICE_ID' instead."
  fi
fi

echo ""
echo "Flutter devices:"
flutter devices
echo ""

if [[ -z "$DEVICE_ID" ]]; then
  echo "No iOS simulator found."
  echo "Usage: ./scripts/run_ios_sim.sh [\"iPhone 17 Pro\"]"
  echo "Tip: run 'xcrun simctl list devices available' to see installed simulators."
  exit 1
fi

SIM_UDID="$(resolve_sim_udid "$DEVICE_ID")"
if [[ -z "$SIM_UDID" ]]; then
  SIM_UDID="$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[A-F0-9-]{36}' | head -1 || true)"
fi

if [[ -n "$SIM_UDID" ]]; then
  echo "Removing previous Cookster install ($BUNDLE_ID) from simulator $SIM_UDID..."
  xcrun simctl uninstall "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
else
  echo "Warning: could not resolve simulator UDID; skipping uninstall."
fi

echo "Launching debug build on: $DEVICE_ID"
exec flutter run --debug -d "$DEVICE_ID"
