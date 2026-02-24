/*
 * MoonBit Native FFI Stubs
 * POSIX系の標準ライブラリ関数のラッパー
 */

#include <stdio.h>

/*
 * stderrを取得する
 * MoonBitからは直接グローバル変数にアクセスできないため、
 * 関数経由で取得する
 */
FILE* moonbit_get_stderr(void) {
    return stderr;
}
