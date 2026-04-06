#!/bin/bash
# Install the typing daemon as a launchd service (macOS).
#
# Usage: ./install.sh /path/to/config.json
#
# This creates a LaunchAgent that starts on login and restarts if it crashes.
# To uninstall: launchctl unload ~/Library/LaunchAgents/com.claude.typing-daemon.plist

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON="$SCRIPT_DIR/typing-daemon.py"
PLIST_NAME="com.claude.typing-daemon"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

if [ $# -lt 1 ]; then
    echo "Usage: $0 /path/to/config.json"
    exit 1
fi

CONFIG="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

if [ ! -f "$CONFIG" ]; then
    echo "Error: Config file not found: $CONFIG"
    exit 1
fi

# Unload existing service if present
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Create the plist
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$DAEMON</string>
        <string>--config</string>
        <string>$CONFIG</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/daemon.log</string>
    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/daemon-error.log</string>
</dict>
</plist>
EOF

# Load the service
launchctl load "$PLIST_PATH"

echo "Typing daemon installed and running."
echo "  Config: $CONFIG"
echo "  Logs:   $SCRIPT_DIR/daemon.log"
echo "  Stop:   launchctl unload $PLIST_PATH"
