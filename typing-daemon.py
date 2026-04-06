#!/usr/bin/env python3
"""
Claude Code Telegram Typing Indicator Daemon

Watches Claude Code transcript files for incoming Telegram messages and sends
"typing" indicators until the agent replies. Runs as a standalone daemon via
launchd (macOS) or systemd (Linux), independent of any Claude session.

How it works:
  1. Tails each agent's active transcript JSONL file
  2. Detects incoming <channel source="plugin:telegram:telegram"> messages
  3. Sends "typing" action to the Telegram API every few seconds
  4. Stops when the agent sends a reply or the timeout expires

Requirements:
  - Python 3.8+
  - Claude Code with the Telegram plugin (plugin:telegram@claude-plugins-official)
  - One Telegram bot token per agent

Usage:
  python3 typing-daemon.py --config config.json
  python3 typing-daemon.py --config config.json --debug
"""

import argparse
import glob
import json
import logging
import os
import re
import sys
import time
import urllib.request
import urllib.error

LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
logger = logging.getLogger("typing-daemon")


def send_typing(token: str, chat_id: str) -> bool:
    """Send a 'typing' chat action to Telegram."""
    url = f"https://api.telegram.org/bot{token}/sendChatAction"
    data = json.dumps({"chat_id": chat_id, "action": "typing"}).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=5)
        return True
    except (urllib.error.URLError, OSError) as e:
        logger.debug(f"Failed to send typing to {chat_id}: {e}")
        return False


def get_latest_transcript(transcript_dir: str):
    """Find the most recently modified .jsonl file in the transcript directory."""
    pattern = os.path.join(transcript_dir, "*.jsonl")
    files = glob.glob(pattern)
    if not files:
        return None
    return max(files, key=os.path.getmtime)


class AgentWatcher:
    """Watches a single agent's transcript for Telegram activity."""

    def __init__(self, name: str, token: str, transcript_dir: str, stale_timeout: int = 90):
        self.name = name
        self.token = token
        self.transcript_dir = os.path.expanduser(transcript_dir)
        self.stale_timeout = stale_timeout
        self.current_file = None
        self.file_pos = 0
        self.typing_chat_id = None
        self.typing_since = 0.0

    def check(self):
        """Check transcript for new lines and update typing state."""
        latest = get_latest_transcript(self.transcript_dir)
        if not latest:
            return

        # If transcript file changed, start reading near the end
        if latest != self.current_file:
            self.current_file = latest
            try:
                size = os.path.getsize(latest)
                self.file_pos = max(0, size - 4096)
            except OSError:
                self.file_pos = 0
            logger.debug(f"[{self.name}] Watching transcript: {latest}")

        try:
            with open(self.current_file, "r") as f:
                f.seek(self.file_pos)
                new_data = f.read()
                self.file_pos = f.tell()
        except OSError:
            return

        if not new_data:
            return

        for line in new_data.strip().split("\n"):
            if not line.strip():
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            self._process_entry(entry)

    def _process_entry(self, entry: dict):
        entry_type = entry.get("type", "")

        if entry_type == "user":
            msg = entry.get("message", {})
            content = msg.get("content", "")
            if isinstance(content, str):
                self._check_channel_message(content)
            elif isinstance(content, list):
                for block in content:
                    text = block.get("text", "")
                    if text:
                        self._check_channel_message(text)

        elif entry_type == "assistant":
            msg = entry.get("message", {})
            content = msg.get("content", [])
            if isinstance(content, list):
                for block in content:
                    if block.get("type") == "tool_use":
                        tool_name = block.get("name", "")
                        if "telegram" in tool_name and "reply" in tool_name:
                            logger.debug(f"[{self.name}] Reply detected — stopping typing")
                            self.typing_chat_id = None

    def _check_channel_message(self, text: str):
        match = re.search(
            r'<channel[^>]*source="plugin:telegram:telegram"[^>]*chat_id="([^"]+)"',
            text,
        )
        if match:
            chat_id = match.group(1)
            self.typing_chat_id = chat_id
            self.typing_since = time.time()
            logger.debug(f"[{self.name}] Incoming message in chat {chat_id} — typing started")
            send_typing(self.token, chat_id)

    def maybe_send_typing(self):
        """Send typing indicator if active, clear if stale."""
        if not self.typing_chat_id:
            return

        if time.time() - self.typing_since > self.stale_timeout:
            logger.debug(f"[{self.name}] Typing expired (>{self.stale_timeout}s)")
            self.typing_chat_id = None
            return

        send_typing(self.token, self.typing_chat_id)


def load_config(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def main():
    parser = argparse.ArgumentParser(description="Telegram typing indicator daemon for Claude Code")
    parser.add_argument("--config", required=True, help="Path to config.json")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format=LOG_FORMAT,
    )

    config = load_config(args.config)
    agents = config.get("agents", {})
    interval = config.get("typing_interval", 4)
    stale_timeout = config.get("stale_timeout", 90)

    if not agents:
        logger.error("No agents configured. Check your config.json.")
        sys.exit(1)

    watchers = []
    for name, cfg in agents.items():
        token = cfg.get("token", "")
        transcript_dir = cfg.get("transcript_dir", "")
        if not token or not transcript_dir:
            logger.warning(f"Agent '{name}' missing token or transcript_dir — skipping")
            continue
        watchers.append(AgentWatcher(name, token, transcript_dir, stale_timeout))
        logger.info(f"Watching agent '{name}' — transcripts: {transcript_dir}")

    logger.info(f"Daemon started. {len(watchers)} agent(s), interval={interval}s, timeout={stale_timeout}s")

    while True:
        for w in watchers:
            try:
                w.check()
                w.maybe_send_typing()
            except Exception as e:
                logger.error(f"[{w.name}] Error: {e}")

        time.sleep(interval)


if __name__ == "__main__":
    main()
