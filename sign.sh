#!/bin/bash
set -e

FRAMEWORK_DIR="$(dirname "$0")/dist/Tquic.framework"
DYLIB="${FRAMEWORK_DIR}/Versions/A/Tquic"
SIGN_IDENTITY="${1:--}"

if [ ! -f "${DYLIB}" ]; then
    echo "[-] Tquic dylib not found at ${DYLIB}"
    echo "    Run ./build.sh && ./package_framework.sh first"
    exit 1
fi

echo "[*] Signing ${DYLIB} ..."

if [ "${SIGN_IDENTITY}" = "-" ]; then
    echo "    Using ad-hoc signature (works with jailbreak/AMFI bypass)"
    codesign -s - -f "${DYLIB}"
    codesign -s - -f "${FRAMEWORK_DIR}/Tquic" 2>/dev/null || true
elif [ "${SIGN_IDENTITY}" = "ldid" ]; then
    if ! command -v ldid &>/dev/null; then
        echo "[-] ldid not found. Install: brew install ldid"
        exit 1
    fi
    ldid -S "${DYLIB}"
else
    echo "    Using identity: ${SIGN_IDENTITY}"
    codesign -f -s "${SIGN_IDENTITY}" "${DYLIB}"
    codesign -f -s "${SIGN_IDENTITY}" "${FRAMEWORK_DIR}/Tquic" 2>/dev/null || true
fi

echo "[+] Signed successfully"
echo ""
echo "  Verify:  codesign -dvvv ${FRAMEWORK_DIR}"
