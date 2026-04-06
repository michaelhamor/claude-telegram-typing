#!/bin/bash
# Uninstall the typing daemon service.
# Supports macOS (launchd) and Linux (systemd).

set -euo pipefail

uninstall_macos() {
    local PLIST_NAME="com.claude.typing-daemon"
    local PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

    if [ -f "$PLIST_PATH" ]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        echo "macOS LaunchAgent removed."
    else
        echo "No macOS LaunchAgent found."
    fi
}

uninstall_linux() {
    local SERVICE_NAME="claude-typing-daemon"
    local SERVICE_PATH="$HOME/.config/systemd/user/$SERVICE_NAME.service"

    if [ -f "$SERVICE_PATH" ]; then
        systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
        systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "$SERVICE_PATH"
        systemctl --user daemon-reload
        echo "systemd user service removed."
    else
        echo "No systemd service found."
    fi
}

case "$(uname -s)" in
    Darwin)
        uninstall_macos
        ;;
    Linux)
        uninstall_linux
        ;;
    *)
        echo "Unknown platform. Kill the process manually:"
        echo "  pkill -f typing-daemon.py"
        ;;
esac
