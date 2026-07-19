#!/bin/bash
set -e

FRAMEWORK_DIR="$(dirname "$0")/dist/Tquic.framework"
DYLIB="${FRAMEWORK_DIR}/Versions/A/Tquic"

if [ ! -f "${DYLIB}" ]; then
    echo "[-] Tquic dylib not found at ${DYLIB}"
    echo "    Run ./build.sh && ./package_framework.sh first (or download from CI)"
    exit 1
fi

echo "[*] Signing for jailbreak with ldid ..."

if ! command -v ldid &>/dev/null; then
    echo "[-] ldid not found. Install: brew install ldid"
    exit 1
fi

ldid -S "${DYLIB}"
ldid -S "${FRAMEWORK_DIR}/Tquic" 2>/dev/null || true

echo "[+] Signed. Copy Tquic.framework into IPA and install."
echo ""
echo "  Verify: ldid -e ${DYLIB}"
