#!/usr/bin/env bash
# tools.sh — Shared tool-check and bootstrap helper for all apk-reverse Bash scripts.
# Source this file in other scripts: source "$SCRIPT_DIR/lib/tools.sh"

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
BOOTSTRAP_PATH="${BOOTSTRAP_PATH:-$SCRIPT_DIR/bootstrap-reverse.sh}"

ensure_tool() {
    local name="$1"
    local manual_hint="${2:-}"

    if command -v "$name" &>/dev/null; then
        return 0
    fi

    echo "INFO: $name not found, attempting auto-install..."
    local bootstrap_rc=0

    if [[ -x "$BOOTSTRAP_PATH" ]]; then
        bash "$BOOTSTRAP_PATH" "$name" --skip-refresh 2>/dev/null || bootstrap_rc=$?
        if [ "$bootstrap_rc" -ne 0 ]; then
            echo "WARNING: bootstrap returned exit code $bootstrap_rc"
        fi
    else
        echo "INFO: bootstrap script not found at $BOOTSTRAP_PATH — skipping auto-install"
    fi

    if ! command -v "$name" &>/dev/null; then
        echo "ERR: $name is not available."
        if [ -n "$manual_hint" ]; then
            echo "  $manual_hint"
        fi
        return 1
    fi

    echo "INFO: $name is ready."
}
