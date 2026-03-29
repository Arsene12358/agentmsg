#!/usr/bin/env bash
set -euo pipefail

INSTALL_BIN="${1:-/usr/local/bin}"
INSTALL_LIB="${AGENTMSG_LIB:-/usr/local/lib/agentmsg}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

do_install() {
    if [ -w "$(dirname "$1")" ]; then
        "$@"
    else
        sudo "$@"
    fi
}

echo "agentmsg installer"
echo "==================="
echo ""

# Check dependencies
if ! command -v jq >/dev/null 2>&1; then
    echo "WARNING: jq is not installed. agentmsg requires jq."
    echo "  Install with: sudo apt-get install jq"
    echo ""
fi

if command -v inotifywait >/dev/null 2>&1; then
    echo "inotifywait detected — low-latency message detection enabled"
else
    echo "inotifywait not found — will use polling (install inotify-tools for faster detection)"
fi
echo ""

# Create lib directory for hooks + templates
do_install mkdir -p "$INSTALL_LIB/hooks"
do_install mkdir -p "$INSTALL_LIB/templates"

# Install binary
do_install cp "$SCRIPT_DIR/bin/agentmsg" "$INSTALL_BIN/agentmsg"
do_install chmod +x "$INSTALL_BIN/agentmsg"
echo "Installed binary to $INSTALL_BIN/agentmsg"

# Install hooks
if [ -d "$SCRIPT_DIR/hooks" ]; then
    do_install cp "$SCRIPT_DIR/hooks"/* "$INSTALL_LIB/hooks/"
    echo "Installed hooks to $INSTALL_LIB/hooks/"
fi

# Install templates
if [ -d "$SCRIPT_DIR/templates" ]; then
    do_install cp "$SCRIPT_DIR/templates"/* "$INSTALL_LIB/templates/"
    echo "Installed templates to $INSTALL_LIB/templates/"
fi

echo ""
echo "Done! Quick start:"
echo "  agentmsg launch ~/my-project"
