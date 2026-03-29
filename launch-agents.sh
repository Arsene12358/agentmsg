#!/usr/bin/env bash
# Convenience wrapper — delegates to agentmsg launch.
set -euo pipefail

command -v agentmsg >/dev/null 2>&1 || {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export PATH="$SCRIPT_DIR/bin:$PATH"
}

exec agentmsg launch "${1:-.}"
