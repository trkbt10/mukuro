#!/bin/bash
# MoonBit native build
# 各 is-main パッケージの cc-flags に -lsqlite3 -lpthread -lz を設定済みのため、
# moon build --target native で直接ビルドが通る。

set -e

cd "$(dirname "$0")/.."

echo "Building..."
moon build --target native

echo "Build complete:"
echo "  - _build/native/debug/build/mukuro.exe"
echo "  - _build/native/debug/build/cmd/main/main.exe"
