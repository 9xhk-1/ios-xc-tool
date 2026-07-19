#!/bin/bash
set -e

PROJECT_DIR="$(dirname "$0")"
SRC_DIR="${PROJECT_DIR}/src"
DEPS_DIR="${PROJECT_DIR}/deps"
IMGUI_DIR="${DEPS_DIR}/imgui"
BUILD_DIR="${PROJECT_DIR}/build"
OUTPUT="${BUILD_DIR}/ios_xc_tool.dylib"

SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)
if [ -z "$SDK_PATH" ]; then
    echo "[-] Xcode / iPhone SDK not found. Install Xcode."
    exit 1
fi

MIN_IOS="12.0"
ARCH="arm64"

if [ ! -d "${IMGUI_DIR}" ]; then
    echo "[-] ImGui not found. Run ./setup.sh first."
    exit 1
fi

echo "[*] Building ios_xc_tool.dylib"
echo "    SDK:     ${SDK_PATH}"
echo "    Arch:    ${ARCH}"
echo "    Min iOS: ${MIN_IOS}"

mkdir -p "${BUILD_DIR}"

IMGUI_SOURCES="
    ${IMGUI_DIR}/imgui.cpp
    ${IMGUI_DIR}/imgui_draw.cpp
    ${IMGUI_DIR}/imgui_widgets.cpp
    ${IMGUI_DIR}/imgui_tables.cpp
    ${IMGUI_DIR}/backends/imgui_impl_metal.mm
"

OUR_SOURCES="
    ${SRC_DIR}/main.mm
    ${SRC_DIR}/OverlayView.mm
"

INCLUDES="-I${IMGUI_DIR} -I${IMGUI_DIR}/backends -I${SRC_DIR}"

FRAMEWORKS="
    -framework UIKit
    -framework Metal
    -framework MetalKit
    -framework QuartzCore
    -framework Foundation
    -framework CoreGraphics
"

xcrun --sdk iphoneos clang++ \
    -arch "${ARCH}" \
    -isysroot "${SDK_PATH}" \
    -miphoneos-version-min="${MIN_IOS}" \
    ${INCLUDES} \
    -shared \
    -install_name @rpath/ios_xc_tool.dylib \
    -o "${OUTPUT}" \
    ${IMGUI_SOURCES} \
    ${OUR_SOURCES} \
    ${FRAMEWORKS} \
    -std=c++17 \
    -fobjc-arc \
    -O2 \
    -fvisibility=hidden

echo ""
echo "+==============================================+"
echo "|  Build SUCCESS                               |"
echo "|  ${OUTPUT}"
echo "+==============================================+"
ls -lh "${OUTPUT}"
echo ""
echo "  To inject into an IPA:"
echo "  1. Unzip target.ipa"
echo "  2. Copy dylib into App bundle"
echo "  3. Use insert_dylib / optool to add load cmd"
echo "  4. Resign & re-zip"
