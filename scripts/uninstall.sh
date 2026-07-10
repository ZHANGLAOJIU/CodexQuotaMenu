#!/bin/bash

set -euo pipefail

LABEL="io.github.zhanglaojiu.codexquotamenu"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
APP_PATH="$HOME/Applications/CodexQuotaMenu.app"

launchctl bootout "gui/$UID" "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"
rm -rf "$APP_PATH"

echo "Uninstalled CodexQuotaMenu. Log files in ~/Library/Logs were kept for troubleshooting."
