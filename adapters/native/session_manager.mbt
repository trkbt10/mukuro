///|
/// Native SessionManager 実装
/// JSONL を source of truth とし、LRU キャッシュで高速化

///|
/// NativeSessionManager
/// History (JSONL) を source of truth とし、Session をキャッシュで保持
pub struct NativeSessionManager {
  base_dir : String
  /// LRU cache for recently accessed sessions
  cache : Map[@types.SessionKey, @types.Session]
  /// Maximum cache entries
  cache_max_size : Int
  /// 現在開いているセッションのレコーダー
  open_recorders : Map[String, NativeHistoryRecorder]
  /// メタデータストア（オプション）
  metadata_store : &@interfaces.HistoryMetadataStore?
}

///|
/// 新規作成
pub fn NativeSessionManager::new(
  base_dir~ : String,
  cache_max_size~ : Int,
) -> NativeSessionManager {
  {
    base_dir,
    cache: {},
    cache_max_size,
    open_recorders: {},
    metadata_store: None,
  }
}

///|
/// メタデータストア付きで新規作成
pub fn NativeSessionManager::new_with_metadata_store(
  base_dir~ : String,
  cache_max_size~ : Int,
  metadata_store~ : &@interfaces.HistoryMetadataStore,
) -> NativeSessionManager {
  {
    base_dir,
    cache: {},
    cache_max_size,
    open_recorders: {},
    metadata_store: Some(metadata_store),
  }
}

///|
/// HistoryRecord 配列から Session を再構築
fn reconstruct_session_from_history(
  key : @types.SessionKey,
  records : Array[@interfaces.HistoryRecord],
) -> @types.Session {
  let mut created_at = 0L
  let mut last_active_at = 0L
  let history : Array[@llm_types.ModelMessage] = []
  // AssistantMessage with tool_calls の処理状態
  let pending_tool_calls : Array[@llm_types.ToolCallRequest] = []
  let mut pending_assistant_index : Int = -1
  let mut pending_assistant_content : String = ""

  for record in records {
    if created_at == 0L {
      created_at = record.timestamp
    }
    if record.timestamp > last_active_at {
      last_active_at = record.timestamp
    }

    match record.record_type {
      @interfaces.HistoryRecordType::UserMessage => {
        // 前の AssistantMessage に tool_calls を反映
        finalize_pending_assistant(
          history, pending_tool_calls, pending_assistant_index, pending_assistant_content,
        )
        pending_assistant_index = -1
        pending_tool_calls.clear()

        let content = extract_payload_content(record.payload)
        let name = extract_payload_name(record.payload)
        history.push(@llm_types.ModelMessage::User(content~, name~))
      }
      @interfaces.HistoryRecordType::AssistantMessage => {
        // 前の AssistantMessage に tool_calls を反映
        finalize_pending_assistant(
          history, pending_tool_calls, pending_assistant_index, pending_assistant_content,
        )
        pending_tool_calls.clear()

        let content = extract_payload_content(record.payload)
        let has_tool_calls = extract_payload_has_tool_calls(record.payload)
        if has_tool_calls {
          // tool_calls は後続の ToolCall レコードから取得するので、一時的に None で追加
          pending_assistant_index = history.length()
          pending_assistant_content = content
          history.push(
            @llm_types.ModelMessage::Assistant(content~, tool_calls=None),
          )
        } else {
          pending_assistant_index = -1
          history.push(
            @llm_types.ModelMessage::Assistant(content~, tool_calls=None),
          )
        }
      }
      @interfaces.HistoryRecordType::ToolCall => {
        // ToolCall を蓄積（直前の AssistantMessage に関連付け）
        let tool_call = extract_tool_call_payload(record.payload)
        pending_tool_calls.push(tool_call)
      }
      @interfaces.HistoryRecordType::ToolResult => {
        // ToolResult の前に pending の AssistantMessage を確定
        finalize_pending_assistant(
          history, pending_tool_calls, pending_assistant_index, pending_assistant_content,
        )
        pending_assistant_index = -1
        pending_tool_calls.clear()

        let (call_id, content) = extract_tool_result_payload(record.payload)
        history.push(
          @llm_types.ModelMessage::ToolResult(tool_call_id=call_id, content~),
        )
      }
      _ => () // SessionMeta, Error は直接 history に入れない
    }
  }

  // ループ終了後、未処理の AssistantMessage があれば確定
  finalize_pending_assistant(
    history, pending_tool_calls, pending_assistant_index, pending_assistant_content,
  )

  // Session を作成し、復元したメッセージを追加
  let session : @types.Session = {
    key,
    history,
    state: @types.SessionState::Active,
    created_at,
    last_active_at,
    metadata: {},
  }
  session
}

///|
/// 保留中の AssistantMessage に tool_calls を反映
fn finalize_pending_assistant(
  history : Array[@llm_types.ModelMessage],
  pending_tool_calls : Array[@llm_types.ToolCallRequest],
  pending_assistant_index : Int,
  pending_assistant_content : String,
) -> Unit {
  if pending_assistant_index >= 0 && pending_tool_calls.length() > 0 {
    let tool_calls = pending_tool_calls.copy()
    history[pending_assistant_index] = @llm_types.ModelMessage::Assistant(
      content=pending_assistant_content,
      tool_calls=Some(tool_calls),
    )
  }
}

///|
/// payload から content を抽出
fn extract_payload_content(payload : Json) -> String {
  match payload {
    Object(obj) =>
      match obj.get("content") {
        Some(String(s)) => s
        _ => ""
      }
    String(s) => s
    _ => ""
  }
}

///|
/// payload から name を抽出
fn extract_payload_name(payload : Json) -> String? {
  match payload {
    Object(obj) =>
      match obj.get("name") {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// payload から ToolResult の情報を抽出
fn extract_tool_result_payload(payload : Json) -> (String, String) {
  match payload {
    Object(obj) => {
      let call_id = match obj.get("call_id") {
        Some(String(s)) => s
        _ => ""
      }
      let content = match obj.get("content") {
        Some(String(s)) => s
        _ => ""
      }
      (call_id, content)
    }
    _ => ("", "")
  }
}

///|
/// payload から has_tool_calls を抽出
fn extract_payload_has_tool_calls(payload : Json) -> Bool {
  match payload {
    Object(obj) =>
      match obj.get("has_tool_calls") {
        Some(True) => true
        _ => false
      }
    _ => false
  }
}

///|
/// payload から ToolCall を抽出
fn extract_tool_call_payload(payload : Json) -> @llm_types.ToolCallRequest {
  match payload {
    Object(obj) => {
      let call_id = match obj.get("call_id") {
        Some(String(s)) => s
        _ => ""
      }
      let tool_name = match obj.get("tool_name") {
        Some(String(s)) => s
        _ => ""
      }
      let arguments = match obj.get("arguments") {
        Some(args) => args
        _ => Json::object({})
      }
      {
        id: call_id,
        name: tool_name,
        arguments,
        kind: @llm_types.ToolCallKind::Function,
      }
    }
    _ =>
      {
        id: "",
        name: "",
        arguments: Json::object({}),
        kind: @llm_types.ToolCallKind::Function,
      }
  }
}

///|
/// セッションIDからレコーダーを取得または作成
fn NativeSessionManager::get_or_create_recorder(
  self : NativeSessionManager,
  session_id : String,
  timestamp : Int64,
) -> NativeHistoryRecorder raise @interfaces.SessionManagerError {
  match self.open_recorders.get(session_id) {
    Some(recorder) => recorder
    None => {
      let recorder = match self.metadata_store {
        Some(store) =>
          NativeHistoryRecorder::new_with_metadata_store(
            base_dir=self.base_dir,
            metadata_store=store,
          )
        None => NativeHistoryRecorder::new(base_dir=self.base_dir)
      }
      let _ = recorder.open_session(session_id~, timestamp~) catch {
        e => raise @interfaces.SessionManagerError::IoError(e.to_string())
      }
      self.open_recorders[session_id] = recorder
      recorder
    }
  }
}

///|
/// JSONL から HistoryRecord を読み込む
fn NativeSessionManager::read_history_records(
  self : NativeSessionManager,
  session_id : String,
) -> Array[@interfaces.HistoryRecord] {
  let reader = match self.metadata_store {
    Some(store) =>
      NativeHistoryReader::new_with_metadata_store(
        base_dir=self.base_dir,
        metadata_store=store,
      )
    None => NativeHistoryReader::new(base_dir=self.base_dir)
  }
  reader.read_session(session_id~) catch {
    _ => []
  }
}

///|
/// キャッシュにセッションを追加（LRU eviction）
fn NativeSessionManager::add_to_cache(
  self : NativeSessionManager,
  key : @types.SessionKey,
  session : @types.Session,
) -> Unit {
  // 簡易的な実装: サイズ超過時は全削除（本来は LRU で古いものから削除）
  if self.cache.length() >= self.cache_max_size {
    self.cache.clear()
  }
  self.cache[key] = session
}

// ============================================================
// SessionManager trait 実装
// ============================================================

///|
pub impl @interfaces.SessionManager for NativeSessionManager with get(self, key) {
  // 1. キャッシュ確認
  match self.cache.get(key) {
    Some(session) => return Some(session)
    None => ()
  }

  // 2. キャッシュミス - History から読み込み
  let session_id = key.to_string()
  let records = self.read_history_records(session_id)
  if records.length() == 0 {
    return None
  }

  // 3. Session を再構築
  let session = reconstruct_session_from_history(key, records)

  // 4. キャッシュに追加
  self.add_to_cache(key, session)

  Some(session)
}

///|
pub impl @interfaces.SessionManager for NativeSessionManager with get_or_create(
  self,
  key,
  now~,
) {
  match self.get(key) {
    Some(session) => session
    None => {
      let session = @types.Session::new(key, now)
      self.add_to_cache(key, session)
      // 新規セッション作成時に SessionMeta を History に記録
      let session_id = key.to_string()
      let recorder = self.get_or_create_recorder(session_id, now) catch {
        _ => return session // レコーダー作成失敗時はキャッシュのみで続行
      }
      let meta_record : @interfaces.HistoryRecord = {
        timestamp: now,
        session_id,
        record_type: @interfaces.HistoryRecordType::SessionMeta,
        payload: Json::object({
          "channel": Json::string(key.channel),
          "chat_id": Json::string(key.chat_id),
        }),
      }
      recorder.record(record=meta_record) catch {
        _ => ()
      }
      session
    }
  }
}

///|
pub impl @interfaces.SessionManager for NativeSessionManager with append_user_message(
  self,
  key,
  content~,
  name~,
  timestamp~,
) {
  let session_id = key.to_string()
  let recorder = self.get_or_create_recorder(session_id, timestamp) catch {
    e => raise e
  }
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: match name {
      Some(n) =>
        Json::object({
          "content": Json::string(content),
          "name": Json::string(n),
        })
      None => Json::object({ "content": Json::string(content) })
    },
  }
  recorder.record(record~) catch {
    e => raise @interfaces.SessionManagerError::IoError(e.to_string())
  }

  // キャッシュ更新
  let session = self.get_or_create(key, now=timestamp) catch { e => raise e }
  session.add_message(@llm_types.ModelMessage::User(content~, name~))
  self.cache[key] = session
}

///|
pub impl @interfaces.SessionManager for NativeSessionManager with append_assistant_message(
  self,
  key,
  content~,
  tool_calls~,
  timestamp~,
) {
  let session_id = key.to_string()
  let recorder = self.get_or_create_recorder(session_id, timestamp) catch {
    e => raise e
  }
  let has_tool_calls = match tool_calls {
    Some(calls) => calls.length() > 0
    None => false
  }
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::AssistantMessage,
    payload: Json::object({
      "content": Json::string(content),
      "has_tool_calls": Json::boolean(has_tool_calls),
    }),
  }
  recorder.record(record~) catch {
    e => raise @interfaces.SessionManagerError::IoError(e.to_string())
  }

  // キャッシュ更新
  let session = self.get_or_create(key, now=timestamp) catch { e => raise e }
  session.add_message(@llm_types.ModelMessage::Assistant(content~, tool_calls~))
  self.cache[key] = session
}

///|
pub impl @interfaces.SessionManager for NativeSessionManager with record_tool_call(
  self,
  key,
  call_id~,
  tool_name~,
  arguments~,
  timestamp~,
) {
  let session_id = key.to_string()
  let recorder = self.get_or_create_recorder(session_id, timestamp) catch {
    e => raise e
  }
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::ToolCall,
    payload: Json::object({
      "call_id": Json::string(call_id),
      "tool_name": Json::string(tool_name),
      "arguments": arguments,
    }),
  }
  recorder.record(record~) catch {
    e => raise @interfaces.SessionManagerError::IoError(e.to_string())
  }
  // ToolCall は history には直接入れない（AssistantMessage の tool_calls で管理）
}

///|
pub impl @interfaces.SessionManager for NativeSessionManager with record_tool_result(
  self,
  key,
  call_id~,
  content~,
  timestamp~,
) {
  let session_id = key.to_string()
  let recorder = self.get_or_create_recorder(session_id, timestamp) catch {
    e => raise e
  }
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::ToolResult,
    payload: Json::object({
      "call_id": Json::string(call_id),
      "content": Json::string(content),
    }),
  }
  recorder.record(record~) catch {
    e => raise @interfaces.SessionManagerError::IoError(e.to_string())
  }

  // キャッシュ更新
  let session = self.get_or_create(key, now=timestamp) catch { e => raise e }
  session.add_message(
    @llm_types.ModelMessage::ToolResult(tool_call_id=call_id, content~),
  )
  self.cache[key] = session
}

///|
pub impl @interfaces.SessionManager for NativeSessionManager with record_error(
  self,
  key,
  message~,
  timestamp~,
) {
  let session_id = key.to_string()
  let recorder = self.get_or_create_recorder(session_id, timestamp) catch {
    e => raise e
  }
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::Error,
    payload: Json::object({ "message": Json::string(message) }),
  }
  recorder.record(record~) catch {
    e => raise @interfaces.SessionManagerError::IoError(e.to_string())
  }
}

///|
pub impl @interfaces.SessionManager for NativeSessionManager with delete(
  self,
  key,
) {
  // キャッシュから削除
  self.cache.remove(key)

  // 開いているレコーダーを閉じる
  let session_id = key.to_string()
  match self.open_recorders.get(session_id) {
    Some(recorder) => {
      recorder.close() catch {
        _ => ()
      }
      self.open_recorders.remove(session_id)
    }
    None => ()
  }

  // メタデータストアから削除
  match self.metadata_store {
    Some(store) => store.delete(session_id~) catch { _ => () }
    None => ()
  }

  // Note: JSONL ファイル自体は削除しない（履歴保持のため）
}

///|
pub impl @interfaces.SessionManager for NativeSessionManager with list_keys(
  self,
) {
  // メタデータストアがあれば使う
  match self.metadata_store {
    Some(store) => {
      let sessions = store.list_recent(limit=1000, offset=0) catch { _ => [] }
      sessions.map(fn(meta) {
        let (channel, chat_id) = @history.split_session_id(meta.session_id)
        @types.SessionKey::new(channel~, chat_id~, user_id=None)
      })
    }
    None =>
      // キャッシュにあるキーのみ返す（フォールバック）
      self.cache.keys().collect()
  }
}

///|
pub impl @interfaces.SessionManager for NativeSessionManager with close_session(
  self,
  key,
) {
  let session_id = key.to_string()
  match self.open_recorders.get(session_id) {
    Some(recorder) => {
      recorder.close() catch {
        _ => ()
      }
      self.open_recorders.remove(session_id)
    }
    None => ()
  }
}
