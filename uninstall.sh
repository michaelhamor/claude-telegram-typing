#!/bin/bash
# Uninstall the typing daemon launchd service.

PLIST_NAME="com.claude.typing-daemon"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

if [ -f "$PLIST_PATH" ]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo "Typing daemon uninstalled."
else
    echo "No daemon installed."
fi
