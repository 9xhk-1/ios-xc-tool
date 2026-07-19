#!/bin/bash
set -e

IMGUI_TAG="v1.91.5"
IMGUI_URL="https://github.com/ocornut/imgui/archive/refs/tags/${IMGUI_TAG}.tar.gz"
DEPS_DIR="$(dirname "$0")/deps"
IMGUI_DIR="${DEPS_DIR}/imgui"

echo "[*] Setting up ios-xc-tool dependencies..."
mkdir -p "${DEPS_DIR}"

if [ ! -d "${IMGUI_DIR}" ]; then
    echo "[*] Downloading Dear ImGui ${IMGUI_TAG}..."
    if command -v curl &>/dev/null; then
        curl -sL "${IMGUI_URL}" -o /tmp/imgui.tar.gz
    else
        wget -q "${IMGUI_URL}" -O /tmp/imgui.tar.gz
    fi
    mkdir -p "${IMGUI_DIR}"
    tar xzf /tmp/imgui.tar.gz -C "${IMGUI_DIR}" --strip-components=1
    rm -f /tmp/imgui.tar.gz
    echo "[+] ImGui ${IMGUI_TAG} downloaded"
else
    echo "[-] ImGui already exists, skipping"
fi

echo "[+] Setup complete. Run ./build.sh to compile."
