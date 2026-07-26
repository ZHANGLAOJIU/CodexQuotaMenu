#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/CodexQuotaMenu-tests.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

CLANG_MODULE_CACHE_PATH="$TMP_DIR/module-cache" \
SWIFT_MODULECACHE_PATH="$TMP_DIR/module-cache" \
swiftc \
    -warnings-as-errors \
    -framework Foundation \
    "$ROOT_DIR/QuotaModel.swift" \
    "$ROOT_DIR/Tests/WindowMappingTests.swift" \
    -o "$TMP_DIR/WindowMappingTests"

"$TMP_DIR/WindowMappingTests"
