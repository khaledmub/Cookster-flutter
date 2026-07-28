#!/usr/bin/env bash
# Print SHA-1/SHA-256 for Firebase Google Sign-In (add SHA-1 in Firebase Console).
set -euo pipefail

echo "=== Debug / profile (default Flutter Android signing) ==="
keytool -list -v \
  -keystore "${HOME}/.android/debug.keystore" \
  -alias androiddebugkey \
  -storepass android \
  -keypass android 2>/dev/null | rg "SHA1:|SHA256:"

KEY_PROPS="$(cd "$(dirname "$0")/.." && pwd)/keyStoreDetails/key.properties"
if [[ -f "$KEY_PROPS" ]]; then
  STORE_FILE=$(rg '^storeFile=' "$KEY_PROPS" | cut -d= -f2-)
  KEY_ALIAS=$(rg '^keyAlias=' "$KEY_PROPS" | cut -d= -f2-)
  STORE_PASS=$(rg '^storePassword=' "$KEY_PROPS" | cut -d= -f2-)
  echo ""
  echo "=== Release (keyStoreDetails/key.properties) ==="
  keytool -list -v \
    -keystore "$STORE_FILE" \
    -alias "$KEY_ALIAS" \
    -storepass "$STORE_PASS" 2>/dev/null | rg "SHA1:|SHA256:"
else
  echo ""
  echo "No keyStoreDetails/key.properties — skip release fingerprint."
fi

echo ""
echo "Add each SHA-1 to Firebase → Project settings → Your apps → Android"
echo "(com.cookster.cooksterapp) → Add fingerprint → download google-services.json"
