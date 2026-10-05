#!/usr/bin/env bash
# tools.sh — Shared tool-check and bootstrap helper for all apk-reverse Bash scripts.
# Source this file in other scripts: source "$SCRIPT_DIR/lib/tools.sh"

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
_TOOLS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_PATH="${BOOTSTRAP_PATH:-$_TOOLS_LIB_DIR/../bootstrap-reverse.sh}"

# Look for a tool in well-known install roots when it is not on PATH.
# Roots: $REVERSE_TOOLS_DIR, ~/Tools, /e/Tools (Git Bash), /mnt/e/Tools (WSL).
# Accepts <name> scripts (also inside versioned <name>*/bin) and <name>*.jar (wrapped in a shell function).
_discover_tool() {
    local name="$1" root dir jar
    for root in "${REVERSE_TOOLS_DIR:-}" "$HOME/Tools" "/e/Tools" "/mnt/e/Tools"; do
        [[ -n "$root" && -d "$root" ]] || continue
        for dir in "$root" "$root/$name"* "$root/$name"*/bin; do
            [[ -d "$dir" ]] || continue
            if [[ -f "$dir/$name" && -x "$dir/$name" ]]; then
                export PATH="$dir:$PATH"
                return 0
            fi
            jar=$(ls "$dir"/"$name"*.jar 2>/dev/null | sort -r | head -n 1)
            if [[ -n "$jar" ]] && command -v java &>/dev/null; then
                eval "$name() { java -jar \"$jar\" \"\$@\"; }"
                return 0
            fi
        done
    done
    return 1
}

ensure_tool() {
    local name="$1"
    local manual_hint="${2:-}"

    if command -v "$name" &>/dev/null || _discover_tool "$name"; then
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
