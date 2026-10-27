#!/bin/bash
# Builds build/SimplePJ.app; a release build is also installed into /Applications (INSTALL=0 to skip).
# Usage: Scripts/bundle.sh [debug|release]   (default: release)
# NOTARIZE=1 Scripts/bundle.sh   also has Apple notarize the app and staples the ticket (Developer ID, notarytool profile "notary")
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
VERSION="1.2.0"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

if [ ! -f Resources/AppIcon.icns ]; then
    swift Scripts/make-icon.swift
fi

ARCH="${ARCH:-$([ "$CONFIG" = release ] && echo universal || echo native)}"
case "$ARCH" in
    universal) ARCH_FLAGS="--arch arm64 --arch x86_64" ;;
    x86_64|intel) ARCH_FLAGS="--arch x86_64" ;;
    arm64) ARCH_FLAGS="--arch arm64" ;;
    *) ARCH_FLAGS="" ;;
esac

# shellcheck disable=SC2086
swift build -c "$CONFIG" $ARCH_FLAGS
# shellcheck disable=SC2086
BIN="$(swift build -c "$CONFIG" $ARCH_FLAGS --show-bin-path)"
APP="${APP:-build/SimplePJ.app}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/SimplePJ" "$APP/Contents/MacOS/SimplePJ"
cp "$BIN/simplepj-mcp" "$APP/Contents/MacOS/simplepj-mcp"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/SimplePJ.sdef "$APP/Contents/Resources/SimplePJ.sdef"
for LPROJ in Resources/*.lproj; do
    [ -d "$LPROJ" ] && cp -R "$LPROJ" "$APP/Contents/Resources/"
done

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>SimplePJ</string>
    <key>CFBundleDisplayName</key><string>SimplePJ</string>
    <key>CFBundleIdentifier</key><string>net.cieadrienm.simplepj</string>
    <key>CFBundleExecutable</key><string>SimplePJ</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>@VERSION@</string>
    <key>CFBundleVersion</key><string>@BUILD@</string>
    <key>CFBundleDevelopmentRegion</key><string>fr</string>
    <key>CFBundleLocalizations</key><array><string>fr</string><string>en</string></array>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSAppleScriptEnabled</key><true/>
    <key>OSAScriptingDefinition</key><string>SimplePJ.sdef</string>
    <key>NSHumanReadableCopyright</key><string>cie Adrien M — Compagnie Adrien M</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>SimplePJ découvre et pilote les vidéoprojecteurs PJLink (port 4352) de votre réseau local et reçoit les commandes OSC de régie.</string>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key><string>net.cieadrienm.simplepj.fleet</string>
            <key>UTTypeDescription</key><string>Parc Vidéoprojecteurs SimplePJ</string>
            <key>UTTypeConformsTo</key><array><string>public.json</string></array>
            <key>UTTypeTagSpecification</key>
            <dict><key>public.filename-extension</key><array><string>simplepj</string></array></dict>
        </dict>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Parc Vidéoprojecteurs SimplePJ</string>
            <key>CFBundleTypeRole</key><string>Editor</string>
            <key>LSHandlerRank</key><string>Owner</string>
            <key>LSItemContentTypes</key><array><string>net.cieadrienm.simplepj.fleet</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST
sed -i '' -e "s/@VERSION@/$VERSION/" -e "s/@BUILD@/$BUILD/" "$APP/Contents/Info.plist"

if [ -z "${SIGN_IDENTITY:-}" ]; then
    IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    DEV_ID_LINE="$(echo "$IDENTITIES" | grep '"Developer ID Application: ' | tail -1 || true)"
    if [ -n "$DEV_ID_LINE" ]; then
        SIGN_HASH="$(echo "$DEV_ID_LINE" | awk '{print $2}')"
        SIGN_IDENTITY="$(echo "$DEV_ID_LINE" | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p')"
    else
        APP_DEV_LINE="$(echo "$IDENTITIES" | grep '"Apple Development: ' | tail -1 || true)"
        SIGN_HASH="$(echo "$APP_DEV_LINE" | awk '{print $2}')"
        SIGN_IDENTITY="$(echo "$APP_DEV_LINE" | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p')"
    fi
    [ -n "${SIGN_IDENTITY:-}" ] || SIGN_IDENTITY="-"
    [ -n "${SIGN_HASH:-}" ] || SIGN_HASH="$SIGN_IDENTITY"
else
    SIGN_HASH="$SIGN_IDENTITY"
fi
case "$SIGN_IDENTITY" in
    "Developer ID Application:"*) SIGN_FLAGS="--timestamp --options runtime" ;;
    *) SIGN_FLAGS="--timestamp=none" ;;
esac
if ! codesign --force $SIGN_FLAGS --sign "$SIGN_HASH" "$APP/Contents/MacOS/simplepj-mcp" "$APP" 2>/tmp/simplepj-codesign.log; then
    echo "warning: signing with '$SIGN_IDENTITY' ($SIGN_HASH) failed; falling back to ad hoc" >&2
    SIGN_IDENTITY="-"
    codesign --force --sign - "$APP/Contents/MacOS/simplepj-mcp" "$APP"
fi
echo "signed: $SIGN_IDENTITY ($SIGN_HASH)" >&2

# NOTARIZE defaults to 1 on release builds signed with Developer ID Application (pass NOTARIZE=0 to skip)
if [ "${NOTARIZE:-$([ "$CONFIG" = release ] && echo 1 || echo 0)}" = "1" ]; then
    case "$SIGN_IDENTITY" in
        "Developer ID Application:"*)
            ditto -c -k --keepParent "$APP" "$APP.notarize.zip"
            xcrun notarytool submit "$APP.notarize.zip" --keychain-profile "${NOTARY_PROFILE:-notary}" --wait
            rm -f "$APP.notarize.zip"
            xcrun stapler staple "$APP"
            echo "notarized and stapled" >&2
            ;;
        *)
            if [ "${NOTARIZE:-}" = "1" ]; then
                echo "error: NOTARIZE=1 needs a Developer ID Application certificate" >&2
                exit 1
            fi
            ;;
    esac
fi

INSTALL_DIR="${INSTALL_DIR:-/Applications}"
if [ "${INSTALL:-$([ "$CONFIG" = release ] && echo 1 || echo 0)}" = 1 ]; then
    TARGET="$INSTALL_DIR/SimplePJ.app"
    if pgrep -f "$TARGET/Contents/MacOS/SimplePJ" >/dev/null; then
        echo "note: SimplePJ is running from $TARGET — quit and reopen it to get this build" >&2
    fi
    rm -rf "$TARGET.new"
    ditto "$APP" "$TARGET.new"
    rm -rf "$TARGET"
    mv "$TARGET.new" "$TARGET"
    echo "installed: $TARGET" >&2
fi
echo "$APP"
