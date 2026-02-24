/*
 * MoonBit Native FFI Stubs
 * POSIX系の標準ライブラリ関数のラッパー
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <spawn.h>
#include <errno.h>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

extern char **environ;

/* グローバル変数: 実行ファイルのパス（main()開始時に設定） */
static char g_exe_path[1024] = "";

/*
 * 実行ファイルのパスを設定する（main()から呼び出す）
 */
void moonbit_set_exe_path(const char* path) {
    if (path) {
        strncpy(g_exe_path, path, sizeof(g_exe_path) - 1);
        g_exe_path[sizeof(g_exe_path) - 1] = '\0';
    }
}

/*
 * 実行ファイルのパスを取得する
 * returns: パス文字列へのポインタ（グローバル変数）
 */
const char* moonbit_get_exe_path(void) {
    // 既に設定済みの場合はそれを返す
    if (g_exe_path[0] != '\0') {
        return g_exe_path;
    }

#ifdef __APPLE__
    // macOS: _NSGetExecutablePath を使用
    uint32_t size = sizeof(g_exe_path);
    if (_NSGetExecutablePath(g_exe_path, &size) == 0) {
        // realpath で正規化
        char resolved[1024];
        if (realpath(g_exe_path, resolved)) {
            strncpy(g_exe_path, resolved, sizeof(g_exe_path) - 1);
        }
        return g_exe_path;
    }
#else
    // Linux: /proc/self/exe を読む
    ssize_t len = readlink("/proc/self/exe", g_exe_path, sizeof(g_exe_path) - 1);
    if (len > 0) {
        g_exe_path[len] = '\0';
        return g_exe_path;
    }
#endif

    return "";
}


/*
 * stderrを取得する
 * MoonBitからは直接グローバル変数にアクセスできないため、
 * 関数経由で取得する
 */
FILE* moonbit_get_stderr(void) {
    return stderr;
}

/*
 * シグナル受信フラグ
 * 0: シグナル未受信
 * 1: SIGTERM受信
 * 2: SIGINT受信
 */
static volatile int g_signal_received = 0;

/*
 * シグナルハンドラ
 */
static void signal_handler(int signum) {
    if (signum == SIGTERM) {
        g_signal_received = 1;
    } else if (signum == SIGINT) {
        g_signal_received = 2;
    }
}

/*
 * シグナルハンドラを設定する
 * returns: 0 on success, -1 on error
 */
int moonbit_setup_signal_handlers(void) {
    struct sigaction sa;
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;

    if (sigaction(SIGTERM, &sa, NULL) == -1) {
        return -1;
    }
    if (sigaction(SIGINT, &sa, NULL) == -1) {
        return -1;
    }
    return 0;
}

/*
 * シグナル受信状態を取得する
 * returns: 0=未受信, 1=SIGTERM, 2=SIGINT
 */
int moonbit_get_signal_received(void) {
    return g_signal_received;
}

/*
 * シグナル受信フラグをリセットする
 */
void moonbit_reset_signal_received(void) {
    g_signal_received = 0;
}

/*
 * 現在のプロセスIDを取得する
 */
int moonbit_getpid(void) {
    return (int)getpid();
}

/*
 * プロセスにシグナルを送信する
 * sig=0でプロセス存在確認
 * returns: 0 on success, -1 on error
 */
int moonbit_kill(int pid, int sig) {
    return kill((pid_t)pid, sig);
}

/*
 * 指定ミリ秒スリープする
 */
void moonbit_sleep_ms(int ms) {
    usleep(ms * 1000);
}

/*
 * UTF-16LE文字列（MoonBit native）からASCII C文字列に変換するヘルパー
 * MoonBit nativeターゲットの文字列はUTF-16LEエンコーディング
 */
static int utf16le_to_ascii(const char* utf16, char* out, int max_len) {
    if (!utf16 || !out || max_len <= 0) return -1;

    const unsigned char* p = (const unsigned char*)utf16;
    int i = 0;

    // UTF-16LEを1文字ずつ処理
    while (i < max_len - 1) {
        unsigned char low = p[0];
        unsigned char high = p[1];

        // null終端チェック (0x0000)
        if (low == 0 && high == 0) break;

        // BMP内のASCII範囲のみサポート (high == 0 && low < 128)
        if (high == 0 && low >= 32 && low < 127) {
            out[i++] = (char)low;
        } else if (high == 0 && low == 0) {
            // null文字
            break;
        }
        // 非ASCII文字はスキップ

        p += 2;  // UTF-16は2バイト単位
    }
    out[i] = '\0';

    return i > 0 ? 0 : -1;
}

/*
 * 指定パスにPIDを書き込む（親ディレクトリも作成）
 * path: MoonBit UTF-16LE文字列
 * returns: 0 on success, -1 on error
 */
int moonbit_write_pid_file(const char* path, int pid) {
    char ascii_path[256];
    if (utf16le_to_ascii(path, ascii_path, sizeof(ascii_path)) != 0) {
        return -1;
    }

    // 親ディレクトリを作成
    char* path_copy = strdup(ascii_path);
    if (!path_copy) return -1;

    char* last_slash = strrchr(path_copy, '/');
    if (last_slash && last_slash != path_copy) {
        *last_slash = '\0';
        mkdir(path_copy, 0755);
    }
    free(path_copy);

    // ファイルを開いて書き込み
    FILE* f = fopen(ascii_path, "w");
    if (!f) return -1;

    fprintf(f, "%d\n", pid);
    fclose(f);
    return 0;
}

/*
 * 指定パスからPIDを読み取る
 * returns: PID on success, -1 on error
 */
int moonbit_read_pid_file(const char* path) {
    char ascii_path[256];
    if (utf16le_to_ascii(path, ascii_path, sizeof(ascii_path)) != 0) {
        return -1;
    }

    FILE* f = fopen(ascii_path, "r");
    if (!f) return -1;

    int pid = -1;
    if (fscanf(f, "%d", &pid) != 1) {
        pid = -1;
    }
    fclose(f);
    return pid;
}

/*
 * 指定パスのファイルが存在するか確認
 * returns: 1 if exists, 0 otherwise
 */
int moonbit_file_exists(const char* path) {
    char ascii_path[256];
    if (utf16le_to_ascii(path, ascii_path, sizeof(ascii_path)) != 0) {
        return 0;
    }
    return access(ascii_path, F_OK) == 0 ? 1 : 0;
}

/*
 * 指定パスのファイルを削除
 * returns: 0 on success, -1 on error
 */
int moonbit_remove_file(const char* path) {
    char ascii_path[256];
    if (utf16le_to_ascii(path, ascii_path, sizeof(ascii_path)) != 0) {
        return -1;
    }
    return remove(ascii_path);
}

/*
 * posix_spawn を使ってデーモンプロセスを起動する
 * fork() の代わりに新しいプロセスを起動することで、MoonBitランタイムの
 * fork安全性問題を回避する
 *
 * pid_path: PIDファイルのパス (UTF-16LE)
 * returns: 成功時は子プロセスのPID、エラー時は-1
 *          moon run 経由での起動は -2（非対応）
 */
int moonbit_spawn_daemon(const char* pid_path_utf16) {
    char exe_path[1024];
    char pid_path[256];
    char pid_path_abs[1024];

    if (utf16le_to_ascii(pid_path_utf16, pid_path, sizeof(pid_path)) != 0) {
        fprintf(stderr, "spawn_daemon: pid_path conversion failed\n");
        return -1;
    }
    // 相対パスは絶対パスに変換（子プロセスのcwd差異でずれないようにする）
    if (pid_path[0] == '/') {
        strncpy(pid_path_abs, pid_path, sizeof(pid_path_abs) - 1);
        pid_path_abs[sizeof(pid_path_abs) - 1] = '\0';
    } else {
        char cwd[768];
        if (!getcwd(cwd, sizeof(cwd))) {
            fprintf(stderr, "spawn_daemon: getcwd failed\n");
            return -1;
        }
        snprintf(pid_path_abs, sizeof(pid_path_abs), "%s/%s", cwd, pid_path);
    }
    const char* current_exe = moonbit_get_exe_path();
    if (!current_exe || current_exe[0] == '\0') {
        fprintf(stderr, "spawn_daemon: failed to resolve executable path\n");
        return -1;
    }
    strncpy(exe_path, current_exe, sizeof(exe_path) - 1);
    exe_path[sizeof(exe_path) - 1] = '\0';

    // 引数を構築: ネイティブバイナリ直実行のみ
    char* argv_direct[] = {
        exe_path,
        "--daemon-child",
        pid_path_abs,
        NULL
    };
    char** argv = argv_direct;
    const char* base = strrchr(exe_path, '/');
    base = base ? (base + 1) : exe_path;
    if (strcmp(base, "moon") == 0) {
        // moon run 経由だとビルドロック競合で子の起動保証が弱いため非対応
        return -2;
    }

    // posix_spawn用の属性とファイルアクションを設定
    posix_spawnattr_t attr;
    posix_spawn_file_actions_t file_actions;

    if (posix_spawnattr_init(&attr) != 0) {
        fprintf(stderr, "spawn_daemon: posix_spawnattr_init failed\n");
        return -1;
    }
    if (posix_spawn_file_actions_init(&file_actions) != 0) {
        posix_spawnattr_destroy(&attr);
        fprintf(stderr, "spawn_daemon: posix_spawn_file_actions_init failed\n");
        return -1;
    }

    // 子プロセスを新しいセッションで起動
    // POSIX_SPAWN_SETSID は macOS/Linux で利用可能
#ifdef POSIX_SPAWN_SETSID
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETSID);
#endif

    // stdin/stdout/stderr を /dev/null にリダイレクト
    int devnull = open("/dev/null", O_RDWR);
    if (devnull >= 0) {
        posix_spawn_file_actions_adddup2(&file_actions, devnull, STDIN_FILENO);
        posix_spawn_file_actions_adddup2(&file_actions, devnull, STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&file_actions, devnull, STDERR_FILENO);
        posix_spawn_file_actions_addclose(&file_actions, devnull);
    }

    pid_t child_pid;
    int spawn_result = posix_spawn(&child_pid, exe_path, &file_actions, &attr, argv, environ);

    posix_spawnattr_destroy(&attr);
    posix_spawn_file_actions_destroy(&file_actions);
    if (devnull >= 0) close(devnull);

    if (spawn_result != 0) {
        fprintf(stderr, "spawn_daemon: posix_spawn failed with %d\n", spawn_result);
        return -1;
    }

    // 子プロセスがPIDファイルを書き込むまで待機（最大5秒）
    for (int i = 0; i < 50; i++) {
        usleep(100 * 1000);  // 100ms

        // PIDファイルが存在するか確認
        if (access(pid_path_abs, F_OK) == 0) {
            // PIDファイルが存在する → 中身を確認
            FILE* f = fopen(pid_path_abs, "r");
            if (f) {
                int written_pid = -1;
                if (fscanf(f, "%d", &written_pid) == 1 && written_pid > 0) {
                    fclose(f);
                    // プロセスが実際に動作しているか確認
                    if (kill(written_pid, 0) == 0) {
                        return written_pid;
                    }
                }
                fclose(f);
            }
        }
    }

    // タイムアウト - 子プロセスが正常に起動しなかった
    fprintf(stderr, "spawn_daemon: timeout waiting for daemon startup\n");
    kill(child_pid, SIGTERM);
    return -1;
}

/*
 * デーモン子プロセスとして初期化する
 * --daemon-child 引数で起動された場合に呼び出される
 *
 * pid_path: PIDファイルのパス (UTF-16LE)
 * returns: 0 on success, -1 on error
 */
int moonbit_daemon_child_init(const char* pid_path_utf16) {
    char pid_path[256];

    if (utf16le_to_ascii(pid_path_utf16, pid_path, sizeof(pid_path)) != 0) {
        return -1;
    }

    // 新しいセッションを作成（まだの場合）
    setsid();

    // シグナルハンドラを設定
    moonbit_setup_signal_handlers();
    signal(SIGCHLD, SIG_IGN);
    signal(SIGHUP, SIG_IGN);
    signal(SIGPIPE, SIG_IGN);

    // 親ディレクトリを作成
    char* path_copy = strdup(pid_path);
    if (path_copy) {
        char* last_slash = strrchr(path_copy, '/');
        if (last_slash && last_slash != path_copy) {
            *last_slash = '\0';
            mkdir(path_copy, 0755);
        }
        free(path_copy);
    }

    // PIDファイルを書き込む
    pid_t my_pid = getpid();
    FILE* f = fopen(pid_path, "w");
    if (!f) {
        return -1;
    }
    fprintf(f, "%d\n", my_pid);
    fclose(f);

    return 0;
}
