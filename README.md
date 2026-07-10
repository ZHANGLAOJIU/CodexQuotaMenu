# Codex Quota Menu

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-AppKit-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/ZHANGLAOJIU/CodexQuotaMenu?style=social)](https://github.com/ZHANGLAOJIU/CodexQuotaMenu/stargazers)

**See your Codex 5-hour and weekly limits directly in the macOS menu bar.**

No browser tab. No manual refresh. No Electron helper. Codex Quota Menu is a tiny native AppKit utility that stays out of the way and keeps the two limits you care about visible:

```text
⚡ 5h71% W95%
```

The percentages in the menu bar are **remaining quota**. Click the item to see used quota, exact reset times, the last sync time, and the active data source.

[中文说明](README.zh-CN.md)

> If this utility saves you a few trips to the usage screen, a star helps other Codex users find it.

## Why this exists

Codex uses two rolling rate-limit windows. The limits are easy to forget while you are deep in a task, and the reset timestamps are not something most people want to keep checking manually. This utility turns that information into an ambient macOS status item.

It was built after a Codex desktop update changed how usage information was exposed. Version 2 reads the same official usage endpoint used by current Codex clients and keeps the local response log as a transparent fallback.

## Features

- Shows remaining quota for the 5-hour and weekly windows in the menu bar.
- Refreshes from the Codex usage service every 30 seconds.
- Shows exact local reset timestamps when clicked.
- Shows both remaining and used percentages.
- Clearly labels whether data came from the official API or the local fallback.
- Falls back to recent Codex response headers when the network is unavailable.
- Launches automatically at login through a per-user LaunchAgent.
- Opens the current Codex desktop app from the menu.
- Uses native Swift and AppKit with no third-party runtime dependencies.
- Stores no credentials, usage history, analytics, or telemetry.

## Menu details

```text
Codex usage

5-hour remaining: 71% (used 29%)
Weekly remaining: 95% (used 5%)

5-hour reset: 2026-07-10 19:07:26
Weekly reset: 2026-07-17 07:23:25
Last sync: 2026-07-10 14:23:15
Data source: Codex official usage API
Plan: plus

Sync now
Open Codex
Quit
```

Dates are formatted in your Mac's local time zone. Values above are illustrative.

## Requirements

- macOS 13 Ventura or newer.
- Codex desktop or Codex CLI signed in with a ChatGPT account.
- Xcode Command Line Tools for building from source.

Install the command line tools if needed:

```bash
xcode-select --install
```

## Install

```bash
git clone https://github.com/ZHANGLAOJIU/CodexQuotaMenu.git
cd CodexQuotaMenu
./scripts/install.sh
```

The installer:

1. Compiles the Swift source locally.
2. Creates an ad-hoc signed `CodexQuotaMenu.app`.
3. Installs it to `~/Applications` without `sudo`.
4. Creates a user LaunchAgent so it starts at login.
5. Starts the menu bar app immediately.

After installation, look for the lightning icon near the right side of the menu bar.

## Update

```bash
cd CodexQuotaMenu
git pull
./scripts/install.sh
```

Running the installer again replaces the existing build and restarts the menu bar process.

## Uninstall

```bash
./scripts/uninstall.sh
```

The uninstaller removes the app and LaunchAgent. Troubleshooting logs are intentionally left in `~/Library/Logs` so you can inspect or delete them yourself.

## How it works

```text
~/.codex/auth.json
        |
        | access token read in memory
        v
https://chatgpt.com/backend-api/wham/usage
        |
        v
CodexQuotaMenu -> macOS NSStatusItem

If the request fails:
~/.codex/logs_2.sqlite -> latest x-codex-* response headers
```

The app reloads `~/.codex/auth.json` for every sync, so a token refreshed by Codex is picked up automatically. The access token is attached only to the official `chatgpt.com` request and is never written by this app.

For compatibility with older and transitional Codex builds, the fallback reader checks both:

- `~/.codex/logs_2.sqlite`
- `~/.codex/sqlite/logs_2.sqlite`

## Privacy and security

Codex Quota Menu is intentionally small enough to audit.

- The app reads your existing Codex access token and account ID from `~/.codex/auth.json`.
- Credentials are held in memory only for the request.
- Requests go only to `https://chatgpt.com/backend-api/wham/usage`.
- Tokens and response bodies are not logged.
- There are no analytics, crash reporters, update services, or third-party SDKs.
- The fallback reads a local SQLite database in read-only usage patterns through `/usr/bin/sqlite3`.

Review [SECURITY.md](SECURITY.md) before installing if you want the full trust model.

## Troubleshooting

### The menu item does not appear

Check whether the process is running:

```bash
launchctl print gui/$(id -u)/io.github.zhanglaojiu.codexquotamenu | grep -E 'state =|pid ='
```

On Macs with many menu bar items, macOS may hide lower-priority items. Temporarily quit another status item or adjust your menu bar manager.

### The value shows `--`

Open Codex and confirm that you are signed in. Then click **Sync now**. If the official request is unavailable and no recent Codex response headers exist, there is no trustworthy value to display.

### Inspect logs

```bash
tail -f ~/Library/Logs/CodexQuotaMenu.debug.log
tail -f ~/Library/Logs/CodexQuotaMenu.err.log
```

The debug log contains sync source and percentages, but never credentials.

### Restart the app

```bash
launchctl kickstart -k gui/$(id -u)/io.github.zhanglaojiu.codexquotamenu
```

## Build manually

```bash
./scripts/build.sh
open build/CodexQuotaMenu.app
```

## Contributing

Bug reports and focused pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. In particular, do not include `auth.json`, access tokens, account IDs, or full Codex logs in an issue.

## Disclaimer

This is an independent community project. It is not affiliated with or endorsed by OpenAI. Codex, ChatGPT, and OpenAI are trademarks of OpenAI. The internal usage endpoint may change in future Codex releases; the fallback and explicit source label are designed to make failures visible rather than silently showing stale data.

## License

[MIT](LICENSE)
