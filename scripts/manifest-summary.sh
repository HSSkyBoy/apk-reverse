#!/usr/bin/env bash
# manifest-summary.sh — Extract key AndroidManifest.xml components and permissions.
# Bash equivalent of manifest-summary.ps1
#
# Usage:
#   bash manifest-summary.sh --manifest <path_to_AndroidManifest.xml>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── 参数 ──────────────────────────────────────────────────────────────────────────

MANIFEST=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST="$2"; shift 2 ;;
        -*) echo "Unknown option: $1"; exit 1 ;;
        *) MANIFEST="$1"; shift ;;
    esac
done

if [[ -z "$MANIFEST" || ! -f "$MANIFEST" ]]; then
    echo "Usage: $0 --manifest <path_to_AndroidManifest.xml>"
    echo ""
    echo "Parses an AndroidManifest.xml and outputs key=value lines:"
    echo "  package, permissions, components (activity/service/receiver/provider),"
    echo "  and main activity entries."
    exit 1
fi

# ─── Helper: get android-namespaced attribute value ────────────────────────────────

get_android_attr() {
    local node="$1"
    local attr="$2"
    # Try android:attr first, then plain attr as fallback
    local val
    val=$(echo "$node" | grep -oP "${attr}=\"[^\"]*\"" | head -1 | sed 's/.*="//;s/"//')
    if [[ -z "$val" ]]; then
        val=$(echo "$node" | grep -oP "android:${attr}=\"[^\"]*\"" | head -1 | sed 's/.*="//;s/"//')
    fi
    echo "$val"
}

# ─── Read manifest ────────────────────────────────────────────────────────────────

MANIFEST_CONTENT=$(cat "$MANIFEST")

# ─── Package ──────────────────────────────────────────────────────────────────────

PACKAGE=$(echo "$MANIFEST_CONTENT" | grep -oP 'package="[^"]*"' | head -1 | sed 's/package="//;s/"//')
echo "package=${PACKAGE:-}"

# ─── Permissions ──────────────────────────────────────────────────────────────────

PERM_COUNT=0
while IFS= read -r line; do
    if echo "$line" | grep -q '<uses-permission'; then
        PERM_NAME=$(echo "$line" | grep -oP 'android:name="[^"]*"' | head -1 | sed 's/android:name="//;s/"//')
        if [[ -n "$PERM_NAME" ]]; then
            echo "permission=$PERM_NAME"
            PERM_COUNT=$((PERM_COUNT + 1))
        fi
    fi
done <<< "$MANIFEST_CONTENT"
echo "permission_count=$PERM_COUNT"

# ─── Components ───────────────────────────────────────────────────────────────────

dump_components() {
    local tag="$1"
    local label="$2"
    local count=0

    # Extract individual <tag ...> blocks (multi-line aware, terminated by >)
    # Use a stateful awk approach to collect full opening tags
    awk -v tag="$tag" '
        BEGIN { in_tag=0; buf="" }
        /<'"$tag"'[ >]/ { in_tag=1; buf=$0 }
        in_tag && />/ { print buf; in_tag=0; buf="" }
        in_tag && !/>/ { buf=buf $0 }
    ' <<< "$MANIFEST_CONTENT" | while IFS= read -r node; do
        local name exported enabled
        name=$(get_android_attr "$node" "name")
        exported=$(get_android_attr "$node" "exported")
        enabled=$(get_android_attr "$node" "enabled")
        echo "${label}=${name:-}"$'\t'"${exported:-}"$'\t'"${enabled:-}"
    done

    # Count lines (subtract header/empty lines)
    count=$(awk -v tag="$tag" '
        /<'"$tag"'[ >]/ { cnt++ }
        END { print cnt }
    ' <<< "$MANIFEST_CONTENT")
    echo "${label}_count=$count"
}

# Process activities first (we also need them for main_activity detection)
dump_components "activity" "activity"
dump_components "service" "service"
dump_components "receiver" "receiver"
dump_components "provider" "provider"

# ─── Main Activities ──────────────────────────────────────────────────────────────

# Find activities with both MAIN action and LAUNCHER category
awk '
    /<activity/ { in_act=1; act_buf=$0; act_name=""; next }
    in_act && /<\/activity>/ { in_act=0 }
    in_act { act_buf=act_buf $0 }
    in_act && />/ {
        # Extract activity name
        if (match(act_buf, /android:name="([^"]+)"/, m)) act_name=m[1]
        else if (match(act_buf, /name="([^"]+)"/, m)) act_name=m[1]

        # Check for MAIN + LAUNCHER
        has_main=0; has_launcher=0
        if (act_buf ~ /android\.intent\.action\.MAIN/) has_main=1
        if (act_buf ~ /android\.intent\.category\.LAUNCHER/) has_launcher=1

        if (has_main && has_launcher && act_name)
            print "main_activity=" act_name

        in_act=0; act_buf=""
    }
' <<< "$MANIFEST_CONTENT"
