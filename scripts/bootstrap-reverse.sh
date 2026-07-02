#!/usr/bin/env bash
# bootstrap-reverse.sh — Interactive tool bootstrap for APK reverse engineering tools.
#
# Usage:
#   bash bootstrap-reverse.sh <tool_name> [--skip-refresh]
#   bash bootstrap-reverse.sh jadx
#   bash bootstrap-reverse.sh frida --skip-refresh

set -euo pipefail

TOOL="${1:-}"
SKIP_REFRESH="${2:-}"

if [[ -z "$TOOL" ]]; then
    echo "Usage: $0 <tool_name> [--skip-refresh]"
    echo "  Supported tools: jadx, apktool, frida, adb"
    exit 1
fi

check_tool() {
    local name="$1"
    command -v "$name" &>/dev/null
}

echo "============================================"
echo "  Bootstrap: $TOOL"
echo "============================================"
echo ""

if check_tool "$TOOL"; then
    echo "INFO: $TOOL is already available on PATH."
    exit 0
fi

echo "INFO: $TOOL is not installed."

case "$TOOL" in
    jadx)
        echo ""
        echo "Install jadx:"
        echo "  Linux (apt):   sudo apt install jadx"
        echo "  macOS (brew):  brew install jadx"
        echo "  Manual:        https://github.com/skylot/jadx/releases/latest"
        echo ""
        read -rp "Attempt auto-install via apt/brew? (y/n) " answer
        if [[ "$answer" =~ ^[Yy] ]]; then
            if command -v apt &>/dev/null; then
                sudo apt install -y jadx
            elif command -v brew &>/dev/null; then
                brew install jadx
            else
                echo "ERR: No supported package manager found. Please install jadx manually."
                exit 1
            fi
        fi
        ;;
    apktool)
        echo ""
        echo "Install apktool:"
        echo "  Linux (apt):   sudo apt install apktool"
        echo "  macOS (brew):  brew install apktool"
        echo "  Manual:        https://apktool.org/"
        echo ""
        read -rp "Attempt auto-install via apt/brew? (y/n) " answer
        if [[ "$answer" =~ ^[Yy] ]]; then
            if command -v apt &>/dev/null; then
                sudo apt install -y apktool
            elif command -v brew &>/dev/null; then
                brew install apktool
            else
                echo "ERR: No supported package manager found. Please install apktool manually."
                exit 1
            fi
        fi
        ;;
    frida)
        echo ""
        echo "Install frida-tools via pip:"
        echo "  pip3 install frida-tools"
        echo ""
        read -rp "Attempt auto-install via pip? (y/n) " answer
        if [[ "$answer" =~ ^[Yy] ]]; then
            PYTHON=""
            if command -v python3 &>/dev/null; then
                PYTHON="python3"
            elif command -v python &>/dev/null; then
                PYTHON="python"
            else
                echo "ERR: Python not found. Please install Python first."
                exit 1
            fi
            "$PYTHON" -m pip install frida-tools
        fi
        ;;
    adb)
        echo ""
        echo "Install adb:"
        echo "  Linux (apt):   sudo apt install adb"
        echo "  macOS (brew):  brew install android-platform-tools"
        echo "  Manual:        https://developer.android.com/studio/releases/platform-tools"
        echo ""
        read -rp "Attempt auto-install via apt/brew? (y/n) " answer
        if [[ "$answer" =~ ^[Yy] ]]; then
            if command -v apt &>/dev/null; then
                sudo apt install -y adb
            elif command -v brew &>/dev/null; then
                brew install android-platform-tools
            else
                echo "ERR: No supported package manager found. Please install adb manually."
                exit 1
            fi
        fi
        ;;
    *)
        echo "ERR: Unknown tool: $TOOL"
        echo "  Supported: jadx, apktool, frida, adb"
        exit 1
        ;;
esac

# Verify after install attempt
if check_tool "$TOOL"; then
    echo "INFO: $TOOL is now available."
else
    echo "WARNING: $TOOL still not found after install attempt."
    echo "  You may need to restart your shell or add it to PATH."
fi
