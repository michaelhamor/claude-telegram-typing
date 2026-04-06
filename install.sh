#!/bin/bash
# Install the typing daemon as a background service.
# Supports macOS (launchd), Linux (systemd), and Windows (via WSL).
#
# Usage: ./install.sh /path/to/config.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON="$SCRIPT_DIR/typing-daemon.py"

if [ $# -lt 1 ]; then
    echo "Usage: $0 /path/to/config.json"
    exit 1
fi

CONFIG="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

if [ ! -f "$CONFIG" ]; then
    echo "Error: Config file not found: $CONFIG"
    exit 1
fi

if [ ! -f "$DAEMON" ]; then
    echo "Error: typing-daemon.py not found in $SCRIPT_DIR"
    exit 1
fi

# Verify python3 exists
if ! command -v python3 &>/dev/null; then
    echo "Error: python3 not found. Install Python 3.8+ first."
    exit 1
fi

# Verify config is valid JSON
python3 -c "import json; json.load(open('$CONFIG'))" 2>/dev/null || {
    echo "Error: Invalid JSON in $CONFIG"
    exit 1
}

install_macos() {
    local PLIST_NAME="com.claude.typing-daemon"
    local PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

    mkdir -p "$HOME/Library/LaunchAgents"

    # Unload existing service
    launchctl unload "$PLIST_PATH" 2>/dev/null || true

    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(command -v python3)</string>
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

    launchctl load "$PLIST_PATH"

    echo "Installed as macOS LaunchAgent."
    echo "  Stop:      launchctl unload $PLIST_PATH"
    echo "  Logs:      $SCRIPT_DIR/daemon.log"
    echo "  Uninstall: ./uninstall.sh"
}

install_linux() {
    local SERVICE_NAME="claude-typing-daemon"
    local SERVICE_PATH="$HOME/.config/systemd/user/$SERVICE_NAME.service"

    mkdir -p "$HOME/.config/systemd/user"

    cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Claude Code Telegram Typing Indicator
After=network.target

[Service]
Type=simple
ExecStart=$(command -v python3) $DAEMON --config $CONFIG
Restart=always
RestartSec=5
StandardOutput=append:$SCRIPT_DIR/daemon.log
StandardError=append:$SCRIPT_DIR/daemon-error.log

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    systemctl --user start "$SERVICE_NAME"

    echo "Installed as systemd user service."
    echo "  Status:    systemctl --user status $SERVICE_NAME"
    echo "  Stop:      systemctl --user stop $SERVICE_NAME"
    echo "  Logs:      $SCRIPT_DIR/daemon.log"
    echo "  Uninstall: ./uninstall.sh"
}

# Detect platform and install
case "$(uname -s)" in
    Darwin)
        install_macos
        ;;
    Linux)
        if command -v systemctl &>/dev/null; then
            install_linux
        else
            echo "Error: systemd not found. Run manually:"
            echo "  python3 $DAEMON --config $CONFIG &"
            exit 1
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        echo "On Windows, run via WSL or manually:"
        echo "  python3 $DAEMON --config $CONFIG"
        echo ""
        echo "To run at startup, add to Task Scheduler or create a .bat file:"
        echo "  pythonw $DAEMON --config $CONFIG"
        exit 0
        ;;
    *)
        echo "Unknown platform: $(uname -s). Run manually:"
        echo "  python3 $DAEMON --config $CONFIG &"
        exit 1
        ;;
esac

echo ""
echo "Typing daemon is running. Test by messaging your bot on Telegram."
