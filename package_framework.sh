#!/bin/bash
set -e

PROJECT_DIR="$(dirname "$0")"
BUILD_DIR="${PROJECT_DIR}/build"
DIST_DIR="${PROJECT_DIR}/dist/Tquic.framework"
FW_NAME="Tquic"
BUNDLE_ID="com.tencent.tquic"
BUNDLE_VERSION="1.4.46"

echo "[*] Packaging Tquic.framework ..."

# Clean dist
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}/Versions/A"

# Copy dylib as framework binary
cp "${BUILD_DIR}/ios_xc_tool.dylib" "${DIST_DIR}/Versions/A/${FW_NAME}"

# Create symlinks (iOS framework layout)
cd "${DIST_DIR}"
ln -sf Versions/Current/${FW_NAME} "${FW_NAME}"
ln -sf Versions/Current/Resources Resources
ln -sf A Versions/Current
mkdir -p Resources

# Generate Info.plist
cat > "${DIST_DIR}/Resources/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${FW_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${FW_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>${BUNDLE_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUNDLE_VERSION}</string>
    <key>MinimumOSVersion</key>
    <string>12.0</string>
</dict>
</plist>
PLIST

echo "[+] Framework packaged at: ${DIST_DIR}"
find "${DIST_DIR}" -type f -o -type l | while read f; do
    echo "  ${f}"
done
