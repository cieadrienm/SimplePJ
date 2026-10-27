#!/bin/bash
# Builds SimplePJ.app in release mode (Universal arm64+x86_64 and Intel x86_64),
# packages build/SimplePJ-<version>.zip and build/SimplePJ-<version>-intel-x86_64.zip,
# computes their SHA-256 checksums, and prints the JSON manifest snippet for SimpleUpdater.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_PATH="$(ARCH=universal ./Scripts/bundle.sh release | tail -1)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
ZIP_PATH="build/SimplePJ-${VERSION}.zip"
INTEL_APP_PATH="build/SimplePJ-Intel/SimplePJ.app"
INTEL_ZIP_PATH="build/SimplePJ-${VERSION}-intel-x86_64.zip"

rm -f "$ZIP_PATH" "$INTEL_ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

ARCH=x86_64 INSTALL=0 APP="$INTEL_APP_PATH" ./Scripts/bundle.sh release >/dev/null
/usr/bin/ditto -c -k --keepParent "$INTEL_APP_PATH" "$INTEL_ZIP_PATH"
INTEL_SHA256="$(shasum -a 256 "$INTEL_ZIP_PATH" | awk '{print $1}')"

cat <<EOF
=== Packaged Release ===
Universal Archive (arm64 + x86_64): $ZIP_PATH
  Architectures: $(lipo -archs "$APP_PATH/Contents/MacOS/SimplePJ")
  SHA-256:       $SHA256
Intel Archive (x86_64):             $INTEL_ZIP_PATH
  Architectures: $(lipo -archs "$INTEL_APP_PATH/Contents/MacOS/SimplePJ")
  SHA-256:       $INTEL_SHA256
Version: $VERSION (build $BUILD)

JSON manifest snippet:
{
  "net.cieadrienm.simplepj": {
    "version": "$VERSION",
    "build": $BUILD,
    "url": "https://github.com/cieadrienm/SimplePJ/releases/download/v$VERSION/SimplePJ-$VERSION.zip",
    "sha256": "$SHA256",
    "notes_fr": "Mise à jour SimplePJ v$VERSION (Universal Apple Silicon + Intel)",
    "notes_en": "SimplePJ v$VERSION update (Universal Apple Silicon + Intel)"
  }
}
EOF
