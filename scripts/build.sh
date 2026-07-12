#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/CodexQuotaMenu.app"
CONTENTS_DIR="$APP_DIR/Contents"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "error: swiftc was not found. Install Xcode Command Line Tools with: xcode-select --install" >&2
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/PkgInfo" "$CONTENTS_DIR/PkgInfo"

swiftc \
    -O \
    -warnings-as-errors \
    -framework AppKit \
    -framework Foundation \
    "$ROOT_DIR/QuotaModel.swift" \
    "$ROOT_DIR/CodexQuotaMenu.swift" \
    "$ROOT_DIR/main.swift" \
    -o "$CONTENTS_DIR/MacOS/CodexQuotaMenu"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built $APP_DIR"
