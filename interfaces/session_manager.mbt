///|
/// セッションマネージャー
/// History を唯一の source of truth とし、Session はその実体化されたビューとして扱う

///|
/// セッションマネージャーエラー
pub(all) suberror SessionManagerError {
  /// I/O 操作失敗
  IoError(String)
  /// セッションが見つからない
  NotFound(String)
  /// 不正な状態
  InvalidState(String)
  /// 初期化されていない
  NotInitialized
} derive(Show)

///|
/// SessionManagerError を文字列に変換
pub fn SessionManagerError::to_string(self : SessionManagerError) -> String {
  match self {
    IoError(msg) => "IoError: \{msg}"
    NotFound(msg) => "NotFound: \{msg}"
    InvalidState(msg) => "InvalidState: \{msg}"
    NotInitialized => "NotInitialized"
  }
}

///|
/// セッションマネージャー トレイト
/// Session と History を統合管理する
pub(open) trait SessionManager {
  /// セッションを取得（なければ History から読み込み）
  /// Returns None if session doesn't exist in History
  get(Self, @types.SessionKey) -> @types.Session? raise SessionManagerError

  /// セッションを取得または新規作成
  get_or_create(Self, @types.SessionKey, now~ : Int64) -> @types.Session raise SessionManagerError

  /// ユーザーメッセージを追加（History + cache 同時更新）
  append_user_message(
    Self,
    @types.SessionKey,
    content~ : String,
    name~ : String?,
    timestamp~ : Int64,
  ) -> Unit raise SessionManagerError

  /// アシスタントメッセージを追加
  append_assistant_message(
    Self,
    @types.SessionKey,
    content~ : String,
    tool_calls~ : Array[@llm_types.ToolCallRequest]?,
    timestamp~ : Int64,
  ) -> Unit raise SessionManagerError

  /// ツール呼び出しを記録
  record_tool_call(
    Self,
    @types.SessionKey,
    call_id~ : String,
    tool_name~ : String,
    arguments~ : Json,
    timestamp~ : Int64,
  ) -> Unit raise SessionManagerError

  /// ツール実行結果を記録
  record_tool_result(
    Self,
    @types.SessionKey,
    call_id~ : String,
    content~ : String,
    timestamp~ : Int64,
  ) -> Unit raise SessionManagerError

  /// エラーを記録
  record_error(Self, @types.SessionKey, message~ : String, timestamp~ : Int64) -> Unit raise SessionManagerError

  /// セッション削除（History + cache）
  delete(Self, @types.SessionKey) -> Unit raise SessionManagerError

  /// 全セッションキーのリスト
  list_keys(Self) -> Array[@types.SessionKey] raise SessionManagerError

  /// セッションをクローズ（開いているファイルハンドルを閉じる）
  close_session(Self, @types.SessionKey) -> Unit raise SessionManagerError
}

///|
/// NoOp SessionManager（テスト用）
pub struct NoOpSessionManager {
  _placeholder : Unit
}

///|
pub fn NoOpSessionManager::new() -> NoOpSessionManager {
  { _placeholder: () }
}

///|
pub impl SessionManager for NoOpSessionManager with get(_self, _key) {
  None
}

///|
pub impl SessionManager for NoOpSessionManager with get_or_create(
  _self,
  key,
  now~,
) {
  @types.Session::new(key, now)
}

///|
pub impl SessionManager for NoOpSessionManager with append_user_message(
  _self,
  _key,
  content~,
  name~,
  timestamp~,
) {
  let _ = content
  let _ = name
  let _ = timestamp
}

///|
pub impl SessionManager for NoOpSessionManager with append_assistant_message(
  _self,
  _key,
  content~,
  tool_calls~,
  timestamp~,
) {
  let _ = content
  let _ = tool_calls
  let _ = timestamp
}

///|
pub impl SessionManager for NoOpSessionManager with record_tool_call(
  _self,
  _key,
  call_id~,
  tool_name~,
  arguments~,
  timestamp~,
) {
  let _ = call_id
  let _ = tool_name
  let _ = arguments
  let _ = timestamp
}

///|
pub impl SessionManager for NoOpSessionManager with record_tool_result(
  _self,
  _key,
  call_id~,
  content~,
  timestamp~,
) {
  let _ = call_id
  let _ = content
  let _ = timestamp
}

///|
pub impl SessionManager for NoOpSessionManager with record_error(
  _self,
  _key,
  message~,
  timestamp~,
) {
  let _ = message
  let _ = timestamp
}

///|
pub impl SessionManager for NoOpSessionManager with delete(_self, _key) {
  ()
}

///|
pub impl SessionManager for NoOpSessionManager with list_keys(_self) {
  []
}

///|
pub impl SessionManager for NoOpSessionManager with close_session(_self, _key) {
  ()
}
