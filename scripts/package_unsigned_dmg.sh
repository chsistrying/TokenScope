#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TokenScope"
BUNDLE_ID="com.tokenscope.app"
VERSION="0.1.0"
MINIMUM_SYSTEM_VERSION="13.0"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_ROOT="${REPO_ROOT}/dist/${APP_NAME}-${VERSION}-unsigned-${TIMESTAMP}"
APP_BUNDLE="${OUTPUT_ROOT}/${APP_NAME}.app"
DMG_STAGING="${OUTPUT_ROOT}/dmg"
DMG_PATH="${OUTPUT_ROOT}/${APP_NAME}-${VERSION}-unsigned.dmg"

cd "${REPO_ROOT}"

swift build -c release --product "${APP_NAME}"
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mkdir -p "${DMG_STAGING}"

cp "${BIN_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod 755 "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MINIMUM_SYSTEM_VERSION}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cp -R "${APP_BUNDLE}" "${DMG_STAGING}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

echo "App bundle: ${APP_BUNDLE}"
echo "Unsigned DMG: ${DMG_PATH}"
