///|
/// Native C FFI 宣言
/// POSIX/libc ベースの低レベルインターフェース

// ============================================================
// 時刻関連
// ============================================================

///|
/// 現在時刻を取得（Unix epoch 秒）
pub extern "C" fn c_time() -> Int64 = "moonbit_time_now"

// ============================================================
// 標準入出力
// ============================================================

///|
/// C FILE ポインタ
#external
pub type CFile

///|
/// 標準出力に文字列を出力
#borrow(s)
pub extern "C" fn c_puts(s : CString) -> Int = "puts"

///|
/// 標準エラーに文字列を出力
#borrow(s)
pub extern "C" fn c_fputs(s : CString, stream : CFile) -> Int = "fputs"

///|
/// stderr を取得（ヘルパー関数が必要）
pub extern "C" fn c_get_stderr() -> CFile = "moonbit_get_stderr"

// ============================================================
// ファイルシステム
// ============================================================

///|
/// ファイルを開く
#borrow(path, mode)
pub extern "C" fn c_fopen(path : CString, mode : CString) -> CFile? = "fopen"

///|
/// ファイルを閉じる
pub extern "C" fn c_fclose(file : CFile) -> Int = "fclose"

///|
/// ファイルから読み込み
pub extern "C" fn c_fread(
  ptr : Bytes,
  size : Int,
  nmemb : Int,
  stream : CFile,
) -> Int = "fread"

///|
/// ファイルに書き込み
pub extern "C" fn c_fwrite(
  ptr : Bytes,
  size : Int,
  nmemb : Int,
  stream : CFile,
) -> Int = "fwrite"

///|
/// ファイルの存在確認
#borrow(path)
pub extern "C" fn c_access(path : CString, mode : Int) -> Int = "access"

///|
/// ファイルを削除
#borrow(path)
pub extern "C" fn c_remove(path : CString) -> Int = "remove"

///|
/// ディレクトリを作成
#borrow(path)
pub extern "C" fn c_mkdir(path : CString, mode : Int) -> Int = "mkdir"

// ============================================================
// プロセス実行
// ============================================================

///|
/// コマンドを実行（popen）
#borrow(command, mode)
pub extern "C" fn c_popen(command : CString, mode : CString) -> CFile? = "popen"

///|
/// popen を閉じる
pub extern "C" fn c_pclose(stream : CFile) -> Int = "pclose"

///|
/// system コマンド実行
#borrow(command)
pub extern "C" fn c_system(command : CString) -> Int = "system"

// ============================================================
// 環境変数
// ============================================================

///|
/// 環境変数を取得
#borrow(name)
pub extern "C" fn c_getenv(name : CString) -> CString? = "getenv"

///|
/// 環境変数を設定
#borrow(name, value)
pub extern "C" fn c_setenv(
  name : CString,
  value : CString,
  overwrite : Int,
) -> Int = "setenv"

///|
/// 環境変数を削除
#borrow(name)
pub extern "C" fn c_unsetenv(name : CString) -> Int = "unsetenv"

// ============================================================
// 文字列変換ヘルパー
// ============================================================

///|
/// C文字列型（null終端）
#external
pub type CString

///|
/// MoonBit String から CString への変換
pub fn string_to_cstring(s : String) -> CString = "%identity"

///|
/// CString から MoonBit String への変換
pub fn cstring_to_string(cs : CString) -> String = "%identity"

// ============================================================
// 定数
// ============================================================

///|
/// F_OK (ファイル存在確認用)
pub let f_ok : Int = 0

///|
/// R_OK (読み取り権限確認用)
pub let r_ok : Int = 4

///|
/// W_OK (書き込み権限確認用)
pub let w_ok : Int = 2

///|
/// X_OK (実行権限確認用)
pub let x_ok : Int = 1

// ============================================================
// シグナル・プロセス管理
// ============================================================

///|
/// シグナルハンドラを設定（SIGTERM/SIGINT）
/// returns: 0 on success, -1 on error
pub extern "C" fn c_setup_signal_handlers() -> Int = "moonbit_setup_signal_handlers"

///|
/// シグナル受信状態を取得
/// returns: 0=未受信, 1=SIGTERM, 2=SIGINT
pub extern "C" fn c_get_signal_received() -> Int = "moonbit_get_signal_received"

///|
/// シグナル受信フラグをリセット
pub extern "C" fn c_reset_signal_received() -> Unit = "moonbit_reset_signal_received"

///|
/// 現在のプロセスIDを取得
pub extern "C" fn c_getpid() -> Int = "moonbit_getpid"

///|
/// プロセスにシグナルを送信
/// sig=0でプロセス存在確認
/// returns: 0 on success, -1 on error
pub extern "C" fn c_kill(pid : Int, sig : Int) -> Int = "moonbit_kill"

///|
/// 指定ミリ秒スリープ
pub extern "C" fn c_sleep_ms(ms : Int) -> Unit = "moonbit_sleep_ms"

///|
/// プロセスを終了
pub extern "C" fn c_exit(status : Int) -> Unit = "exit"

// ============================================================
// シグナル定数
// ============================================================

///|
/// SIGTERM（終了要求）
pub let sigterm : Int = 15

///|
/// SIGINT（割り込み）
pub let sigint : Int = 2

// ============================================================
// PIDファイル操作（シンプルなFFI）
// ============================================================

///|
/// PIDファイルを書き込む（親ディレクトリも作成）
/// returns: 0 on success, -1 on error
#borrow(path)
pub extern "C" fn c_write_pid_file(path : CString, pid : Int) -> Int = "moonbit_write_pid_file"

///|
/// PIDファイルを読み取る
/// returns: PID on success, -1 on error
#borrow(path)
pub extern "C" fn c_read_pid_file(path : CString) -> Int = "moonbit_read_pid_file"

///|
/// ファイルが存在するか確認
/// returns: 1 if exists, 0 otherwise
#borrow(path)
pub extern "C" fn c_file_exists(path : CString) -> Int = "moonbit_file_exists"

///|
/// ファイルを削除
/// returns: 0 on success, -1 on error
#borrow(path)
pub extern "C" fn c_remove_file(path : CString) -> Int = "moonbit_remove_file"

///|
/// ファイル権限を変更
/// mode 例: 0o600 / 0o644
/// returns: 0 on success, -1 on error
#borrow(path)
pub extern "C" fn c_chmod_file(path : CString, mode : Int) -> Int = "moonbit_chmod_file"

// ============================================================
// posix_spawn ベースのデーモン起動
// ============================================================

///|
/// posix_spawn でデーモンプロセスを起動
/// fork() の代わりに新しいプロセスを起動することで、MoonBitランタイムの
/// fork安全性問題を回避する
/// returns: 成功時は子プロセスのPID、エラー時は-1
#borrow(pid_path)
pub extern "C" fn c_spawn_daemon(pid_path : CString) -> Int = "moonbit_spawn_daemon"

///|
/// デーモン子プロセスとして初期化（--daemon-child 引数で起動時）
/// returns: 0 on success, -1 on error
#borrow(pid_path)
pub extern "C" fn c_daemon_child_init(pid_path : CString) -> Int = "moonbit_daemon_child_init"

///|
/// 実行ファイルの絶対パスを取得
pub extern "C" fn c_get_exe_path() -> CString = "moonbit_get_exe_path"

// ============================================================
// ローカルIPC（Unix domain socket）
// ============================================================

///|
/// IPCサーバーを起動（UNIX socket bind/listen）
/// returns: 0 on success, -1 on error
pub extern "C" fn c_ipc_server_start() -> Int = "moonbit_ipc_server_start"

///|
/// IPCサーバーを1回ポーリングしてコマンド処理
/// token_pid: 現行認証トークン（ランダム値）
/// prev_token_pid: 直前認証トークン（ローテーション直後のgrace用、無効時は負値）
/// session_id: デーモンセッション識別子
/// returns: 0=処理なし, 1=status処理, 2=stop処理, 3=認証失敗, 4=不明コマンド, -1=エラー
pub extern "C" fn c_ipc_server_poll(
  token_pid : Int,
  prev_token_pid : Int,
  session_id : Int,
  pid : Int,
  uptime_sec : Int,
) -> Int = "moonbit_ipc_server_poll"

///|
/// IPCサーバーを停止し、ソケットファイルを削除
/// returns: 0 on success, -1 on error
pub extern "C" fn c_ipc_server_cleanup() -> Int = "moonbit_ipc_server_cleanup"

///|
/// IPCクライアントリクエストを送信
/// command: 1=status, 2=stop
/// response_buf: レスポンス受信用バッファ
/// returns: 受信バイト数（>=0）、エラー時-1
#borrow(response_buf)
pub extern "C" fn c_ipc_client_request(
  token_pid : Int,
  session_id : Int,
  command : Int,
  response_buf : Bytes,
  response_buf_len : Int,
) -> Int = "moonbit_ipc_client_request"

///|
/// Gateway状態スナップショットを書き込む
/// state: 1=running, 0=stopped
/// returns: 0 on success, -1 on error
pub extern "C" fn c_write_gateway_snapshot(
  pid : Int,
  uptime_sec : Int,
  state : Int,
) -> Int = "moonbit_write_gateway_snapshot"

///|
/// IPC認証トークンを書き込む
/// returns: 0 on success, -1 on error
pub extern "C" fn c_write_gateway_token(token : Int) -> Int = "moonbit_write_gateway_token"

///|
/// IPC認証トークン（メタ付き）を書き込む
/// format: "<token> <session_id> <issued_at>\n"
/// returns: 0 on success, -1 on error
pub extern "C" fn c_write_gateway_token_record(
  token : Int,
  session_id : Int,
  issued_at : Int64,
) -> Int = "moonbit_write_gateway_token_record"

///|
/// IPC認証トークンを生成する
/// returns: token (>0) on success, fallback含め常に正値を返す
pub extern "C" fn c_generate_gateway_token() -> Int = "moonbit_generate_gateway_token"

///|
/// IPC認証トークンを読み取る
/// returns: token on success, -1 on error
pub extern "C" fn c_read_gateway_token() -> Int = "moonbit_read_gateway_token"

///|
/// IPCセッションIDを読み取る
/// tokenファイルが旧形式の場合は -1
pub extern "C" fn c_read_gateway_session_id() -> Int = "moonbit_read_gateway_session_id"

///|
/// IPC認証監査ログを追記する
/// event: 1=auth_failed, 2=rate_limited_start, 3=rate_limited_end
/// value: 補助値（失敗回数やblock秒）
pub extern "C" fn c_append_gateway_auth_audit(
  now : Int64,
  event : Int,
  value : Int,
) -> Int = "moonbit_append_gateway_auth_audit"
