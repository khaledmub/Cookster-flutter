#!/usr/bin/env bash
# Start a lightweight Android emulator for Cookster development.
set -euo pipefail

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

AVD="${1:-Cookster_Lite}"

if pgrep -f "qemu-system.*${AVD}" >/dev/null 2>&1; then
  echo "Emulator already running for AVD: $AVD"
  adb devices
  exit 0
fi

echo "Starting $AVD (close iOS Simulator first if this keeps crashing)..."
exec "$ANDROID_HOME/emulator/emulator" \
  -avd "$AVD" \
  -memory 1536 \
  -cores 2 \
  -gpu host \
  -no-boot-anim \
  -no-audio \
  -no-snapshot-load
