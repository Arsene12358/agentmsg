#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${1:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo "inotifywait detected — agentmsg will use it for low-latency message detection"
else
    echo "inotifywait not found — agentmsg will use polling (install inotify-tools for faster detection)"
fi
echo ""

# Install binary
if [ -w "$INSTALL_DIR" ]; then
    cp "$SCRIPT_DIR/bin/agentmsg" "$INSTALL_DIR/agentmsg"
    chmod +x "$INSTALL_DIR/agentmsg"
else
    echo "Need sudo to install to $INSTALL_DIR"
    sudo cp "$SCRIPT_DIR/bin/agentmsg" "$INSTALL_DIR/agentmsg"
    sudo chmod +x "$INSTALL_DIR/agentmsg"
fi

echo "Installed agentmsg to $INSTALL_DIR/agentmsg"

# Copy hook templates next to the binary so install_hook() can find them
HOOKS_DEST="$(dirname "$INSTALL_DIR/agentmsg")/../hooks"
if [ -d "$SCRIPT_DIR/hooks" ]; then
    mkdir -p "$HOOKS_DEST" 2>/dev/null || sudo mkdir -p "$HOOKS_DEST"
    cp "$SCRIPT_DIR/hooks"/* "$HOOKS_DEST/" 2>/dev/null || sudo cp "$SCRIPT_DIR/hooks"/* "$HOOKS_DEST/"
    echo "Installed hook templates to $HOOKS_DEST/"
fi

echo ""
echo "Done! Next steps:"
echo "  1. export AGENTMSG_IDENTITY=claude   # or codex"
echo "  2. agentmsg init /path/to/your/repo"
echo "  3. See README.md for usage patterns"
