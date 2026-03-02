#!/bin/bash
# MoonBit native build with SQLite3 linking
# cc-link-flags が効かない問題の回避策

set -e

cd "$(dirname "$0")/.."

# 1. moon build でコンパイル（リンクは失敗するので無視）
echo "Compiling..."
moon build --target native 2>&1 || true

# 2. 手動でリンク
echo "Linking with -lsqlite3..."
/usr/bin/cc -o _build/native/debug/build/mukuro.exe \
  -I"$HOME/.moon/include" -g -fwrapv -fno-strict-aliasing -Wno-unused-value \
  "$HOME/.moon/lib/libmoonbitrun.o" \
  _build/native/debug/build/mukuro.c \
  _build/native/debug/build/runtime.o \
  _build/native/debug/build/.mooncakes/moonbitlang/async/internal/c_buffer/libc_buffer.a \
  _build/native/debug/build/.mooncakes/moonbitlang/async/internal/env_util/libenv_util.a \
  _build/native/debug/build/.mooncakes/moonbitlang/async/internal/os_string/libos_string.a \
  _build/native/debug/build/.mooncakes/moonbitlang/async/os_error/libos_error.a \
  _build/native/debug/build/.mooncakes/moonbitlang/async/internal/fd_util/libfd_util.a \
  _build/native/debug/build/.mooncakes/moonbitlang/async/internal/time/libtime.a \
  _build/native/debug/build/.mooncakes/moonbitlang/async/internal/event_loop/libevent_loop.a \
  _build/native/debug/build/.mooncakes/moonbitlang/async/socket/libsocket.a \
  _build/native/debug/build/.mooncakes/moonbitlang/async/tls/libtls.a \
  _build/native/debug/build/.mooncakes/mizchi/sqlite/libsqlite.a \
  _build/native/debug/build/lib/dirs/libdirs.a \
  _build/native/debug/build/adapters/native/libnative.a \
  _build/native/debug/build/core/tools/libtools.a \
  -lm "$HOME/.moon/lib/libbacktrace.a" \
  -lsqlite3 -lpthread -lz 2>&1

echo "Build complete: _build/native/debug/build/mukuro.exe"
