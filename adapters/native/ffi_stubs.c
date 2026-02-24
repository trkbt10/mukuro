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
#include <time.h>
#include <sys/socket.h>
#include <sys/un.h>

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
static int g_ipc_server_fd = -1;
static int64_t g_last_auth_failure_audit_at = 0;
static int g_last_ipc_request_session_id = -1;
static int g_last_ipc_request_token = -1;
static char g_last_ipc_client_id[64] = "unknown";

int moonbit_append_gateway_auth_audit_detail(
    int64_t now,
    int event,
    int value,
    const char* source_utf16,
    const char* client_id_utf16,
    int session_id,
    const char* reason_utf16,
    int token_age_sec,
    int64_t blocked_until
);

/*
 * IPC認証トークンを生成する
 * /dev/urandom を優先し、失敗時は時刻とPIDベースでフォールバック
 */
int moonbit_generate_gateway_token(void) {
    unsigned int token = 0;

    int random_fd = open("/dev/urandom", O_RDONLY);
    if (random_fd >= 0) {
        ssize_t read_size = read(random_fd, &token, sizeof(token));
        close(random_fd);
        if (read_size == (ssize_t)sizeof(token)) {
            token &= 0x7fffffffU;
            if (token == 0) token = 1;
            return (int)token;
        }
    }

    struct timespec ts;
    if (clock_gettime(CLOCK_REALTIME, &ts) == 0) {
        token = (unsigned int)ts.tv_nsec ^ (unsigned int)getpid() ^ (unsigned int)time(NULL);
    } else {
        token = (unsigned int)getpid() ^ (unsigned int)time(NULL);
    }

    token &= 0x7fffffffU;
    if (token == 0) token = 1;
    return (int)token;
}

/*
 * 現在時刻（Unix epoch秒）
 */
int64_t moonbit_time_now(void) {
    return (int64_t)time(NULL);
}

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
 * ASCII文字列をUTF-16LEバイト列へ変換する
 */
static int ascii_to_utf16le_bytes(const char* ascii, char* out, int out_len) {
    if (!ascii || !out || out_len <= 0) return -1;
    int written = 0;
    for (int i = 0; ascii[i] != '\0'; i++) {
        if (written + 2 >= out_len) break;
        out[written++] = (unsigned char)ascii[i];
        out[written++] = 0;
    }
    return written;
}

/*
 * client_idとして許可する文字のみ通す
 */
static void sanitize_client_id(char* s) {
    if (!s) return;
    for (int i = 0; s[i] != '\0'; i++) {
        char c = s[i];
        int ok =
            (c >= 'a' && c <= 'z') ||
            (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9') ||
            c == '-' || c == '_' || c == '.' || c == ':';
        if (!ok) s[i] = '_';
    }
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
 * 指定パスにテキストを書き込む（親ディレクトリも作成）
 * path/content: MoonBit UTF-16LE文字列
 * returns: 0 on success, -1 on error
 */
int moonbit_write_text_file(const char* path, const char* content) {
    char ascii_path[512];
    if (utf16le_to_ascii(path, ascii_path, sizeof(ascii_path)) != 0) {
        return -1;
    }

    char ascii_content[8192];
    if (utf16le_to_ascii(content, ascii_content, sizeof(ascii_content)) != 0) {
        return -1;
    }

    char* path_copy = strdup(ascii_path);
    if (!path_copy) return -1;

    char* last_slash = strrchr(path_copy, '/');
    if (last_slash && last_slash != path_copy) {
        *last_slash = '\0';
        mkdir(path_copy, 0755);
    }
    free(path_copy);

    FILE* f = fopen(ascii_path, "w");
    if (!f) return -1;
    if (fputs(ascii_content, f) < 0) {
        fclose(f);
        return -1;
    }
    fclose(f);
    return 0;
}

/*
 * 指定パスからテキストを読み込む
 * path: MoonBit UTF-16LE文字列
 * buffer: 出力バッファ（UTF-8/ASCII bytes）
 * returns: bytes read on success, -1 on error
 */
int moonbit_read_text_file(const char* path, unsigned char* buffer, int buffer_len) {
    if (!buffer || buffer_len <= 0) return -1;

    char ascii_path[512];
    if (utf16le_to_ascii(path, ascii_path, sizeof(ascii_path)) != 0) {
        return -1;
    }

    FILE* f = fopen(ascii_path, "r");
    if (!f) return -1;

    size_t n = fread(buffer, 1, (size_t)buffer_len, f);
    if (ferror(f)) {
        fclose(f);
        return -1;
    }
    fclose(f);
    return (int)n;
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
 * 指定パスのファイル権限を変更
 * returns: 0 on success, -1 on error
 */
int moonbit_chmod_file(const char* path, int mode) {
    char ascii_path[256];
    if (utf16le_to_ascii(path, ascii_path, sizeof(ascii_path)) != 0) {
        return -1;
    }
    return chmod(ascii_path, (mode_t)mode);
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

/*
 * UTF-16LE文字列からASCIIに変換し、必要なら絶対パス化する
 * returns: 0 on success, -1 on error
 */
static int get_default_ipc_socket_path(char* out, int out_len) {
    char cwd[768];
    if (!out || out_len <= 0) return -1;
    if (!getcwd(cwd, sizeof(cwd))) return -1;
    snprintf(out, out_len, "%s/.mukuro/gateway.sock", cwd);
    return 0;
}

static int get_default_gateway_snapshot_path(char* out, int out_len) {
    char cwd[768];
    if (!out || out_len <= 0) return -1;
    if (!getcwd(cwd, sizeof(cwd))) return -1;
    snprintf(out, out_len, "%s/.mukuro/gateway-state.json", cwd);
    return 0;
}

static int get_default_gateway_token_path(char* out, int out_len) {
    char cwd[768];
    if (!out || out_len <= 0) return -1;
    if (!getcwd(cwd, sizeof(cwd))) return -1;
    snprintf(out, out_len, "%s/.mukuro/gateway.token", cwd);
    return 0;
}

static int get_default_gateway_auth_log_path(char* out, int out_len) {
    char cwd[768];
    if (!out || out_len <= 0) return -1;
    if (!getcwd(cwd, sizeof(cwd))) return -1;
    snprintf(out, out_len, "%s/.mukuro/gateway-auth.log", cwd);
    return 0;
}

/*
 * リクエスト1行をパースする
 * format: "<token> <session_id> <command>\n"
 */
static int parse_request_line(
    const char* line,
    int* token_pid,
    int* session_id,
    char* command,
    int command_len,
    char* client_id,
    int client_id_len
) {
    if (!line || !token_pid || !session_id || !command || !client_id) return -1;
    *token_pid = -1;
    *session_id = -1;
    command[0] = '\0';
    strncpy(client_id, "unknown", client_id_len - 1);
    client_id[client_id_len - 1] = '\0';

    int matched = sscanf(line, "%d %d %31s %63s", token_pid, session_id, command, client_id);
    if (matched < 3) return -1;
    sanitize_client_id(client_id);
    return 0;
}

/*
 * IPCサーバーを起動する（UNIX domain socket）
 */
int moonbit_ipc_server_start(void) {
    char socket_path[1024];
    if (get_default_ipc_socket_path(socket_path, sizeof(socket_path)) != 0) {
        return -1;
    }

    // 親ディレクトリ作成
    char* copy = strdup(socket_path);
    if (!copy) return -1;
    char* last_slash = strrchr(copy, '/');
    if (last_slash && last_slash != copy) {
        *last_slash = '\0';
        mkdir(copy, 0755);
    }
    free(copy);

    if (g_ipc_server_fd >= 0) {
        close(g_ipc_server_fd);
        g_ipc_server_fd = -1;
    }

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);

    unlink(socket_path);

    if (bind(fd, (struct sockaddr*)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -1;
    }
    if (listen(fd, 16) != 0) {
        close(fd);
        unlink(socket_path);
        return -1;
    }
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags >= 0) {
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
    g_ipc_server_fd = fd;
    return 0;
}

/*
 * IPCサーバーを1回ポーリングする
 */
int moonbit_ipc_server_poll(
    int token_pid,
    int prev_token_pid,
    int session_id,
    int pid,
    int uptime_sec
) {
    if (g_ipc_server_fd < 0) return -1;

    int client = accept(g_ipc_server_fd, NULL, NULL);
    if (client < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return 0;
        }
        return -1;
    }

    char req[256] = {0};
    ssize_t read_len = read(client, req, sizeof(req) - 1);
    if (read_len <= 0) {
        close(client);
        return 0;
    }
    req[read_len] = '\0';

    int request_token_pid = -1;
    int request_session_id = -1;
    char command[32];
    char client_id[64];
    if (parse_request_line(
        req, &request_token_pid, &request_session_id, command, sizeof(command), client_id, sizeof(client_id)
    ) != 0) {
        g_last_ipc_request_token = -1;
        g_last_ipc_request_session_id = -1;
        strncpy(g_last_ipc_client_id, "unknown", sizeof(g_last_ipc_client_id) - 1);
        g_last_ipc_client_id[sizeof(g_last_ipc_client_id) - 1] = '\0';
        const char* resp = "ERR malformed\n";
        write(client, resp, strlen(resp));
        close(client);
        return 4;
    }

    g_last_ipc_request_token = request_token_pid;
    g_last_ipc_request_session_id = request_session_id;
    strncpy(g_last_ipc_client_id, client_id, sizeof(g_last_ipc_client_id) - 1);
    g_last_ipc_client_id[sizeof(g_last_ipc_client_id) - 1] = '\0';

    if (
        request_session_id != session_id ||
        (request_token_pid != token_pid && request_token_pid != prev_token_pid)
    ) {
        const char* resp = "ERR unauthorized\n";
        write(client, resp, strlen(resp));
        close(client);
        return 3;
    }

    if (strcmp(command, "status") == 0) {
        char resp[256];
        snprintf(resp, sizeof(resp), "OK running %d %d\n", pid, uptime_sec);
        write(client, resp, strlen(resp));
        close(client);
        return 1;
    }
    if (strcmp(command, "stop") == 0) {
        const char* resp = "OK stopping\n";
        write(client, resp, strlen(resp));
        close(client);
        return 2;
    }

    const char* resp = "ERR unknown\n";
    write(client, resp, strlen(resp));
    close(client);
    return 4;
}

/*
 * IPCサーバーを停止し、ソケットファイルを削除する
 */
int moonbit_ipc_server_cleanup(void) {
    char socket_path[1024];
    if (get_default_ipc_socket_path(socket_path, sizeof(socket_path)) != 0) {
        return -1;
    }
    if (g_ipc_server_fd >= 0) {
        close(g_ipc_server_fd);
        g_ipc_server_fd = -1;
    }
    unlink(socket_path);
    return 0;
}

/*
 * IPCクライアントでリクエスト送信
 */
int moonbit_ipc_client_request(
    int token_pid,
    int session_id,
    int command,
    const char* client_id_utf16,
    char* response_buf,
    int response_buf_len
) {
    if (!response_buf || response_buf_len <= 0) return -1;

    char socket_path[1024];
    if (get_default_ipc_socket_path(socket_path, sizeof(socket_path)) != 0) return -1;

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);

    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -1;
    }

    char req[256];
    const char* command_text = "status";
    char client_id[64] = "cli-unknown";
    if (client_id_utf16) {
        char parsed[64];
        if (utf16le_to_ascii(client_id_utf16, parsed, sizeof(parsed)) == 0) {
            strncpy(client_id, parsed, sizeof(client_id) - 1);
            client_id[sizeof(client_id) - 1] = '\0';
            sanitize_client_id(client_id);
        }
    }
    if (command == 2) {
        command_text = "stop";
    }
    snprintf(req, sizeof(req), "%d %d %s %s\n", token_pid, session_id, command_text, client_id);
    if (write(fd, req, strlen(req)) < 0) {
        close(fd);
        return -1;
    }

    char ascii_resp[256];
    ssize_t n = read(fd, ascii_resp, sizeof(ascii_resp) - 1);
    if (n < 0) {
        close(fd);
        return -1;
    }
    ascii_resp[n] = '\0';

    int out = 0;
    out = ascii_to_utf16le_bytes(ascii_resp, response_buf, response_buf_len);
    close(fd);
    return out;
}

/*
 * 直近IPCリクエストのclient_idを取得する
 */
int moonbit_ipc_get_last_client_id(char* response_buf, int response_buf_len) {
    if (!response_buf || response_buf_len <= 0) return -1;
    return ascii_to_utf16le_bytes(g_last_ipc_client_id, response_buf, response_buf_len);
}

/*
 * 直近IPCリクエストのsession_idを取得する
 */
int moonbit_ipc_get_last_session_id(void) {
    return g_last_ipc_request_session_id;
}

/*
 * Gateway状態スナップショットを書き込む
 */
int moonbit_write_gateway_snapshot(int pid, int uptime_sec, int state) {
    char path[1024];
    if (get_default_gateway_snapshot_path(path, sizeof(path)) != 0) {
        return -1;
    }

    char* copy = strdup(path);
    if (!copy) return -1;
    char* last_slash = strrchr(copy, '/');
    if (last_slash && last_slash != copy) {
        *last_slash = '\0';
        mkdir(copy, 0755);
    }
    free(copy);

    FILE* f = fopen(path, "w");
    if (!f) return -1;
    fprintf(
        f,
        "{\"state\":\"%s\",\"pid\":%d,\"uptime_sec\":%d}\n",
        state == 1 ? "running" : "stopped",
        pid,
        uptime_sec
    );
    fclose(f);
    return 0;
}

/*
 * IPC認証トークンを書き込む
 */
int moonbit_write_gateway_token(int token) {
    char path[1024];
    if (get_default_gateway_token_path(path, sizeof(path)) != 0) {
        return -1;
    }

    char* copy = strdup(path);
    if (!copy) return -1;
    char* last_slash = strrchr(copy, '/');
    if (last_slash && last_slash != copy) {
        *last_slash = '\0';
        mkdir(copy, 0755);
    }
    free(copy);

    FILE* f = fopen(path, "w");
    if (!f) return -1;
    fprintf(f, "%d\n", token);
    fclose(f);
    chmod(path, 0600);
    return 0;
}

/*
 * IPC認証トークン（メタ付き）を書き込む
 * format: "<token> <session_id> <issued_at>\n"
 */
int moonbit_write_gateway_token_record(int token, int session_id, int64_t issued_at) {
    char path[1024];
    if (get_default_gateway_token_path(path, sizeof(path)) != 0) {
        return -1;
    }

    char* copy = strdup(path);
    if (!copy) return -1;
    char* last_slash = strrchr(copy, '/');
    if (last_slash && last_slash != copy) {
        *last_slash = '\0';
        mkdir(copy, 0755);
    }
    free(copy);

    FILE* f = fopen(path, "w");
    if (!f) return -1;
    fprintf(f, "%d %d %lld\n", token, session_id, (long long)issued_at);
    fclose(f);
    chmod(path, 0600);
    return 0;
}

/*
 * IPC認証トークンを読み取る
 */
int moonbit_read_gateway_token(void) {
    char path[1024];
    if (get_default_gateway_token_path(path, sizeof(path)) != 0) {
        return -1;
    }

    struct stat st;
    if (stat(path, &st) != 0) {
        return -1;
    }
    if (st.st_uid != getuid()) {
        return -1;
    }
    if ((st.st_mode & (S_IRWXG | S_IRWXO)) != 0) {
        return -1;
    }

    FILE* f = fopen(path, "r");
    if (!f) return -1;
    int token = -1;
    if (fscanf(f, "%d", &token) != 1) {
        token = -1;
    }
    fclose(f);
    return token;
}

/*
 * IPCセッションIDを読み取る
 * tokenファイルが旧形式（tokenのみ）の場合は -1
 */
int moonbit_read_gateway_session_id(void) {
    char path[1024];
    if (get_default_gateway_token_path(path, sizeof(path)) != 0) {
        return -1;
    }

    struct stat st;
    if (stat(path, &st) != 0) {
        return -1;
    }
    if (st.st_uid != getuid()) {
        return -1;
    }
    if ((st.st_mode & (S_IRWXG | S_IRWXO)) != 0) {
        return -1;
    }

    FILE* f = fopen(path, "r");
    if (!f) return -1;
    int token = -1;
    int session_id = -1;
    if (fscanf(f, "%d %d", &token, &session_id) < 2) {
        session_id = -1;
    }
    fclose(f);
    return session_id;
}

/*
 * IPC認証監査ログを追記する
 * event: 1=auth_failed, 2=rate_limited_start, 3=rate_limited_end
 * value: 補助値（失敗回数やblock秒）
 */
int moonbit_append_gateway_auth_audit(int64_t now, int event, int value) {
    return moonbit_append_gateway_auth_audit_detail(
        now,
        event,
        value,
        "ipc",
        "unknown",
        -1,
        event == 2 ? "rate_limited" : (event == 3 ? "rate_limit_end" : "unauthorized"),
        -1,
        -1
    );
}

/*
 * IPC/Control API認証監査ログ（詳細）を追記する
 */
int moonbit_append_gateway_auth_audit_detail(
    int64_t now,
    int event,
    int value,
    const char* source_utf16,
    const char* client_id_utf16,
    int session_id,
    const char* reason_utf16,
    int token_age_sec,
    int64_t blocked_until
) {
    char source[32] = "unknown";
    char client_id[96] = "unknown";
    char reason[64] = "unknown";
    if (source_utf16) {
        char parsed[32];
        if (utf16le_to_ascii(source_utf16, parsed, sizeof(parsed)) == 0) {
            strncpy(source, parsed, sizeof(source) - 1);
            source[sizeof(source) - 1] = '\0';
        }
    }
    if (client_id_utf16) {
        char parsed[96];
        if (utf16le_to_ascii(client_id_utf16, parsed, sizeof(parsed)) == 0) {
            strncpy(client_id, parsed, sizeof(client_id) - 1);
            client_id[sizeof(client_id) - 1] = '\0';
        }
    }
    if (reason_utf16) {
        char parsed[64];
        if (utf16le_to_ascii(reason_utf16, parsed, sizeof(parsed)) == 0) {
            strncpy(reason, parsed, sizeof(reason) - 1);
            reason[sizeof(reason) - 1] = '\0';
        }
    }
    sanitize_client_id(client_id);

    if (event == 1 && strcmp(source, "ipc") == 0 && strcmp(reason, "unauthorized") == 0) {
        if (now - g_last_auth_failure_audit_at < 2) {
            return 0;
        }
        g_last_auth_failure_audit_at = now;
    }

    char path[1024];
    if (get_default_gateway_auth_log_path(path, sizeof(path)) != 0) {
        return -1;
    }

    char* copy = strdup(path);
    if (!copy) return -1;
    char* last_slash = strrchr(copy, '/');
    if (last_slash && last_slash != copy) {
        *last_slash = '\0';
        mkdir(copy, 0755);
    }
    free(copy);

    FILE* f = fopen(path, "a");
    if (!f) return -1;

    const char* event_text = "unknown";
    if (event == 1) {
        event_text = "auth_failed";
    } else if (event == 2) {
        event_text = "rate_limited_start";
    } else if (event == 3) {
        event_text = "rate_limited_end";
    } else if (event == 4) {
        event_text = "forbidden";
    }

    fprintf(
        f,
        "{\"ts\":%lld,\"event\":\"%s\",\"source\":\"%s\",\"client_id\":\"%s\",\"session_id\":%d,\"reason\":\"%s\",\"value\":%d,\"token_age_sec\":%d,\"blocked_until\":%lld}\n",
        (long long)now,
        event_text,
        source,
        client_id,
        session_id,
        reason,
        value,
        token_age_sec,
        (long long)blocked_until
    );
    fclose(f);
    chmod(path, 0600);
    return 0;
}
