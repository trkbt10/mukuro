///|
/// 履歴管理オプション
pub(all) struct HistoryOptions {
  /// 最大メッセージ数
  max_messages : Int
  /// 最大トークン数（概算）
  max_tokens : Int
  /// 古いメッセージを切り捨てるかどうか
  truncate_old : Bool
}

///|
/// デフォルトの履歴オプション
pub fn HistoryOptions::default() -> HistoryOptions {
  { max_messages: 100, max_tokens: 100000, truncate_old: true }
}

///|
/// 履歴マネージャ
/// セッション履歴の追加・取得・切り捨てを管理
pub struct HistoryManager {
  options : HistoryOptions
}

///|
/// HistoryManagerを新規作成
pub fn HistoryManager::new(options~ : HistoryOptions) -> HistoryManager {
  { options, }
}

///|
/// デフォルトのHistoryManager
pub fn HistoryManager::default() -> HistoryManager {
  { options: HistoryOptions::default() }
}

///|
/// メッセージを履歴に追加
pub fn HistoryManager::add_message(
  self : HistoryManager,
  session : @types.Session,
  message : @llm_types.ModelMessage,
) -> @types.Session {
  session.history.push(message)
  // 必要に応じて切り捨て
  if self.options.truncate_old &&
    session.history.length() > self.options.max_messages {
    self.truncate_history(session)
  } else {
    session
  }
}

///|
/// 履歴を切り捨て（古いメッセージから削除）
pub fn HistoryManager::truncate_history(
  self : HistoryManager,
  session : @types.Session,
) -> @types.Session {
  let history = session.history
  let excess = history.length() - self.options.max_messages
  if excess <= 0 {
    return session
  }
  // 新しい履歴を作成（古いメッセージを除去）
  let new_history : Array[@llm_types.ModelMessage] = []
  for i in excess..<history.length() {
    new_history.push(history[i])
  }
  {
    key: session.key,
    history: new_history,
    state: session.state,
    created_at: session.created_at,
    last_active_at: session.last_active_at,
    metadata: session.metadata,
  }
}

///|
/// 最新のN件のメッセージを取得
pub fn get_recent_messages(
  session : @types.Session,
  count : Int,
) -> Array[@llm_types.ModelMessage] {
  let history = session.history
  let start = if history.length() > count {
    history.length() - count
  } else {
    0
  }
  let result : Array[@llm_types.ModelMessage] = []
  for i in start..<history.length() {
    result.push(history[i])
  }
  result
}

///|
/// 履歴からシステムメッセージを除外
pub fn filter_non_system_messages(
  history : Array[@llm_types.ModelMessage],
) -> Array[@llm_types.ModelMessage] {
  let result : Array[@llm_types.ModelMessage] = []
  for msg in history {
    match msg {
      @llm_types.ModelMessage::System(_) => ()
      _ => result.push(msg)
    }
  }
  result
}

///|
/// メッセージの概算トークン数を計算（簡易版）
pub fn estimate_tokens(message : @llm_types.ModelMessage) -> Int {
  let content = match message {
    @llm_types.ModelMessage::System(text) => text
    @llm_types.ModelMessage::User(content~, ..) => content
    @llm_types.ModelMessage::Assistant(content~, ..) => content
    @llm_types.ModelMessage::ToolResult(content~, ..) => content
  }
  // 簡易的に4文字で1トークンとして計算
  (content.to_string().length() + 3) / 4
}

///|
/// 履歴全体の概算トークン数を計算
pub fn estimate_history_tokens(history : Array[@llm_types.ModelMessage]) -> Int {
  let mut total = 0
  for msg in history {
    total = total + estimate_tokens(msg)
  }
  total
}
