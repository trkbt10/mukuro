///|
/// Native C FFI - ローカルIPC
/// Unix domain socket IPC for daemon communication

// ============================================================
// IPCサーバー
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

// ============================================================
// IPCクライアント
// ============================================================

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
  client_id : CString,
  response_buf : Bytes,
  response_buf_len : Int,
) -> Int = "moonbit_ipc_client_request"

///|
/// IPCクライアントリクエストを送信 - UTF-8 Bytes版
/// command: 1=status, 2=stop
/// response_buf: レスポンス受信用バッファ (UTF-8)
/// returns: 受信バイト数（>=0）、エラー時-1
#borrow(client_id, response_buf)
pub extern "C" fn c_ipc_client_request_bytes(
  token_pid : Int,
  session_id : Int,
  command : Int,
  client_id : Bytes,
  response_buf : Bytes,
  response_buf_len : Int,
) -> Int = "moonbit_ipc_client_request_bytes"

///|
/// 直近IPCリクエストの client_id を取得
/// response_buf: UTF-16LE文字列バッファ
/// returns: 受信バイト数（>=0）、エラー時-1
#borrow(response_buf)
pub extern "C" fn c_ipc_get_last_client_id(
  response_buf : Bytes,
  response_buf_len : Int,
) -> Int = "moonbit_ipc_get_last_client_id"

///|
/// 直近IPCリクエストの session_id を取得
pub extern "C" fn c_ipc_get_last_session_id() -> Int = "moonbit_ipc_get_last_session_id"

// ============================================================
// Gateway状態管理
// ============================================================

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

// ============================================================
// 認証監査ログ
// ============================================================

///|
/// IPC認証監査ログを追記する
/// event: 1=auth_failed, 2=rate_limited_start, 3=rate_limited_end
/// value: 補助値（失敗回数やblock秒）
pub extern "C" fn c_append_gateway_auth_audit(
  now : Int64,
  event : Int,
  value : Int,
) -> Int = "moonbit_append_gateway_auth_audit"

///|
/// IPC/Control API 認証監査ログ（詳細）を追記する
/// event: 1=auth_failed, 2=rate_limited_start, 3=rate_limited_end, 4=forbidden
/// source: "ipc" | "control_api" | "daemon"
/// reason: "unauthorized" | "forbidden" | "rate_limited" | "rate_limit_end" | "malformed"
/// token_age_sec/blocked_until: 未使用時は負値
#borrow(source, client_id, reason)
pub extern "C" fn c_append_gateway_auth_audit_detail(
  now : Int64,
  event : Int,
  value : Int,
  source : CString,
  client_id : CString,
  session_id : Int,
  reason : CString,
  token_age_sec : Int,
  blocked_until : Int64,
) -> Int = "moonbit_append_gateway_auth_audit_detail"

///|
/// IPC/Control API 認証監査ログ（詳細）を追記する - UTF-8 Bytes版
#borrow(source, client_id, reason)
pub extern "C" fn c_append_gateway_auth_audit_detail_bytes(
  now : Int64,
  event : Int,
  value : Int,
  source : Bytes,
  client_id : Bytes,
  session_id : Int,
  reason : Bytes,
  token_age_sec : Int,
  blocked_until : Int64,
) -> Int = "moonbit_append_gateway_auth_audit_detail_bytes"
