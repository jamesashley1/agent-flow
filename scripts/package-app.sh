#!/bin/bash
set -euo pipefail

# Build and package Agent Flow as a macOS .app bundle
#
# Usage:
#   ./scripts/package-app.sh                    # build only
#   ./scripts/package-app.sh --sign "Developer ID Application: Name (TEAMID)"
#   ./scripts/package-app.sh --sign "Developer ID Application: Name (TEAMID)" --notarize

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$ROOT_DIR/AgentFlowApp"
BUILD_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$BUILD_DIR/Agent Flow.app"
VERSION=$(grep -A1 CFBundleShortVersionString "$APP_DIR/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

SIGN_IDENTITY=""
NOTARIZE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --sign) SIGN_IDENTITY="$2"; shift 2 ;;
        --notarize) NOTARIZE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "==> Building Agent Flow v${VERSION} (release)..."
cd "$APP_DIR"
swift build -c release 2>&1 | tail -3

echo "==> Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$APP_DIR/.build/release/AgentFlow" "$APP_BUNDLE/Contents/MacOS/AgentFlow"
cp "$APP_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Strip debug symbols for smaller binary
strip -x "$APP_BUNDLE/Contents/MacOS/AgentFlow" 2>/dev/null || true

BINARY_SIZE=$(du -sh "$APP_BUNDLE/Contents/MacOS/AgentFlow" | cut -f1)
echo "    Binary size: $BINARY_SIZE"

# Code sign
if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "==> Signing with: $SIGN_IDENTITY"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" \
        --entitlements /dev/stdin "$APP_BUNDLE" <<'ENTITLEMENTS'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS
    echo "    Signed."
else
    echo "    Skipping code signing (use --sign to sign)"
    # Ad-hoc sign so macOS doesn't reject it outright
    codesign --force --sign - "$APP_BUNDLE"
fi

# Create zip for distribution
echo "==> Creating zip..."
cd "$BUILD_DIR"
ZIP_NAME="AgentFlow-v${VERSION}-mac.zip"
rm -f "$ZIP_NAME"
ditto -c -k --keepParent "Agent Flow.app" "$ZIP_NAME"
ZIP_SIZE=$(du -sh "$ZIP_NAME" | cut -f1)
echo "    $ZIP_NAME ($ZIP_SIZE)"

# Notarize
if [[ "$NOTARIZE" == true && -n "$SIGN_IDENTITY" ]]; then
    echo "==> Notarizing..."
    xcrun notarytool submit "$BUILD_DIR/$ZIP_NAME" \
        --keychain-profile "notarytool-profile" \
        --wait
    echo "==> Stapling..."
    xcrun stapler staple "$APP_BUNDLE"
    # Re-zip after stapling
    rm -f "$ZIP_NAME"
    ditto -c -k --keepParent "Agent Flow.app" "$ZIP_NAME"
    echo "    Notarized and stapled."
fi

echo ""
echo "Done! Output:"
echo "  App:  $APP_BUNDLE"
echo "  Zip:  $BUILD_DIR/$ZIP_NAME"
