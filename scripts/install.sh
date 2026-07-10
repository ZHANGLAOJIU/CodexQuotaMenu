#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodexQuotaMenu.app"
APP_DEST="$HOME/Applications/$APP_NAME"
LABEL="io.github.zhanglaojiu.codexquotamenu"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs"

"$ROOT_DIR/scripts/build.sh"

mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$LOG_DIR"
launchctl bootout "gui/$UID" "$PLIST_PATH" 2>/dev/null || true

rm -rf "$APP_DEST"
ditto "$ROOT_DIR/build/$APP_NAME" "$APP_DEST"

TMP_PLIST="$(mktemp "/tmp/$LABEL.XXXXXX")"
trap 'rm -f "$TMP_PLIST"' EXIT
plutil -create xml1 "$TMP_PLIST"
plutil -insert Label -string "$LABEL" "$TMP_PLIST"
plutil -insert ProgramArguments -array "$TMP_PLIST"
plutil -insert ProgramArguments.0 -string "$APP_DEST/Contents/MacOS/CodexQuotaMenu" "$TMP_PLIST"
plutil -insert RunAtLoad -bool true "$TMP_PLIST"
plutil -insert StandardErrorPath -string "$LOG_DIR/CodexQuotaMenu.err.log" "$TMP_PLIST"
plutil -insert StandardOutPath -string "$LOG_DIR/CodexQuotaMenu.out.log" "$TMP_PLIST"
mv "$TMP_PLIST" "$PLIST_PATH"
trap - EXIT

launchctl bootstrap "gui/$UID" "$PLIST_PATH"
launchctl kickstart -k "gui/$UID/$LABEL"

echo "Installed CodexQuotaMenu. Look for the lightning icon in your macOS menu bar."
