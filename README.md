# claude-telegram-typing

Typing indicator daemon for Claude Code's Telegram plugin. Shows "typing..." in Telegram while your Claude agent is processing a message.

## The Problem

When you message a Claude Code agent via Telegram, there's no feedback that it's working on your request. The chat looks idle until the reply arrives — which can take seconds to minutes depending on the task.

## The Solution

A lightweight daemon that watches Claude Code's transcript files and sends Telegram "typing" indicators while the agent is processing. No hooks, no plugin modifications, no dependencies beyond Python 3.8+.

### How it works

1. Tails each agent's active `.jsonl` transcript file
2. Detects incoming `<channel source="plugin:telegram:telegram">` messages
3. Sends `sendChatAction: typing` every 4 seconds
4. Stops when the agent sends a reply or the timeout expires (default 90s)

## Setup

### 1. Create a config file

Copy `config.example.json` to `config.json` and fill in your agents:

```json
{
  "agents": {
    "my-agent": {
      "token": "123456:ABC-your-bot-token",
      "transcript_dir": "~/.claude/projects/-Users-you-project-dir"
    }
  },
  "typing_interval": 4,
  "stale_timeout": 90
}
```

**Finding your transcript directory:** Claude Code stores transcripts in `~/.claude/projects/` using a path-encoded directory name. If your agent runs from `/Users/you/agents/bot`, the transcript dir is `~/.claude/projects/-Users-you-agents-bot`.

### 2. Install as a launchd service (macOS)

```bash
chmod +x install.sh
./install.sh config.json
```

This creates a LaunchAgent that starts on login, restarts on crash, and runs independently of any Claude session.

### 3. Test it

Message your bot on Telegram. You should see "typing..." appear within a few seconds.

### Uninstall

```bash
./uninstall.sh
```

## Manual usage

```bash
# Run in foreground
python3 typing-daemon.py --config config.json

# Run with debug logging
python3 typing-daemon.py --config config.json --debug
```

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `typing_interval` | `4` | Seconds between typing indicator pings |
| `stale_timeout` | `90` | Seconds before auto-stopping typing (safety net) |
| `agents.*.token` | — | Telegram bot token for this agent |
| `agents.*.transcript_dir` | — | Path to the Claude Code transcript directory |

## Multi-agent setup

Add one entry per agent. Each agent needs its own bot token (created via [@BotFather](https://t.me/BotFather)):

```json
{
  "agents": {
    "nova": {
      "token": "111:AAA...",
      "transcript_dir": "~/.claude/projects/-Users-you"
    },
    "sable": {
      "token": "222:BBB...",
      "transcript_dir": "~/.claude/projects/-Users-you-agents-sable"
    },
    "ada": {
      "token": "333:CCC...",
      "transcript_dir": "~/.claude/projects/-Users-you-agents-ada"
    }
  }
}
```

## Requirements

- Python 3.8+
- macOS (for launchd install) or any OS for manual usage
- Claude Code with the Telegram plugin (`--channels plugin:telegram@claude-plugins-official`)

## License

MIT
