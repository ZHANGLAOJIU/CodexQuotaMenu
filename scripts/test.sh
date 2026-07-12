#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/CodexQuotaMenu-tests.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

swiftc \
    -warnings-as-errors \
    -framework Foundation \
    "$ROOT_DIR/QuotaModel.swift" \
    "$ROOT_DIR/Tests/WindowMappingTests.swift" \
    -o "$TMP_DIR/WindowMappingTests"

"$TMP_DIR/WindowMappingTests"
