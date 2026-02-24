///|
/// 子セッション管理
/// Sub-Agentの親子関係とステータスを追跡する

///|
/// 子セッションのステータス
pub(all) enum ChildSessionStatus {
  Pending
  Running
  Completed
  Failed(String)
  Cancelled
}

///|
pub impl Show for ChildSessionStatus with output(self, logger) {
  match self {
    Pending => logger.write_string("pending")
    Running => logger.write_string("running")
    Completed => logger.write_string("completed")
    Failed(msg) => logger.write_string("failed: \{msg}")
    Cancelled => logger.write_string("cancelled")
  }
}

///|
/// 子セッション
/// Sub-Agentの実行状態を管理
pub(all) struct ChildSession {
  /// 親セッションID
  parent_id : String
  /// 子セッションID
  child_id : String
  /// メッセージ履歴
  messages : Array[@types.ModelMessage]
  /// ステータス
  mut status : ChildSessionStatus
  /// 最終結果
  mut result : String?
  /// 作成時刻
  created_at : Int64
  /// 更新時刻
  mut updated_at : Int64
}

///|
/// 新しい子セッションを作成
pub fn ChildSession::new(
  parent_id~ : String,
  child_id~ : String,
  timestamp~ : Int64,
) -> ChildSession {
  {
    parent_id,
    child_id,
    messages: [],
    status: Pending,
    result: None,
    created_at: timestamp,
    updated_at: timestamp,
  }
}

///|
/// メッセージを追加
pub fn ChildSession::add_message(
  self : ChildSession,
  message : @types.ModelMessage,
) -> Unit {
  self.messages.push(message)
}

///|
/// ステータスを更新
pub fn ChildSession::set_status(
  self : ChildSession,
  status : ChildSessionStatus,
  timestamp : Int64,
) -> Unit {
  self.status = status
  self.updated_at = timestamp
}

///|
/// 結果を設定
pub fn ChildSession::set_result(
  self : ChildSession,
  result : String,
  timestamp : Int64,
) -> Unit {
  self.result = Some(result)
  self.status = Completed
  self.updated_at = timestamp
}

///|
/// エラーで失敗
pub fn ChildSession::set_failed(
  self : ChildSession,
  error : String,
  timestamp : Int64,
) -> Unit {
  self.status = Failed(error)
  self.updated_at = timestamp
}

///|
/// キャンセル
pub fn ChildSession::cancel(self : ChildSession, timestamp : Int64) -> Unit {
  self.status = Cancelled
  self.updated_at = timestamp
}

///|
/// 完了しているかどうか
pub fn ChildSession::is_finished(self : ChildSession) -> Bool {
  match self.status {
    Completed | Failed(_) | Cancelled => true
    _ => false
  }
}

///|
/// 子セッションマネージャ
/// 複数の子セッションを管理
pub struct ChildSessionManager {
  /// アクティブな子セッション
  sessions : Map[String, ChildSession]
  /// 次のセッションID
  mut next_id : Int
  /// 親セッションID
  parent_id : String
}

///|
/// 新しいマネージャを作成
pub fn ChildSessionManager::new(parent_id~ : String) -> ChildSessionManager {
  { sessions: {}, next_id: 1, parent_id }
}

///|
/// 新しい子セッションIDを生成
pub fn ChildSessionManager::generate_id(self : ChildSessionManager) -> String {
  let id = "child_\{self.parent_id}_\{self.next_id}"
  self.next_id = self.next_id + 1
  id
}

///|
/// 子セッションを作成
pub fn ChildSessionManager::create_session(
  self : ChildSessionManager,
  timestamp : Int64,
) -> ChildSession {
  let child_id = self.generate_id()
  let session = ChildSession::new(
    parent_id=self.parent_id,
    child_id~,
    timestamp~,
  )
  self.sessions[child_id] = session
  session
}

///|
/// 子セッションを取得
pub fn ChildSessionManager::get_session(
  self : ChildSessionManager,
  child_id : String,
) -> ChildSession? {
  self.sessions.get(child_id)
}

///|
/// 全ての子セッションを取得
pub fn ChildSessionManager::list_sessions(
  self : ChildSessionManager,
) -> Array[ChildSession] {
  let result : Array[ChildSession] = []
  for _, session in self.sessions {
    result.push(session)
  }
  result
}

///|
/// 完了していない子セッションを取得
pub fn ChildSessionManager::list_active_sessions(
  self : ChildSessionManager,
) -> Array[ChildSession] {
  let result : Array[ChildSession] = []
  for _, session in self.sessions {
    if not(session.is_finished()) {
      result.push(session)
    }
  }
  result
}

///|
/// 子セッションを削除
pub fn ChildSessionManager::remove_session(
  self : ChildSessionManager,
  child_id : String,
) -> Bool {
  if self.sessions.contains(child_id) {
    self.sessions.remove(child_id)
    true
  } else {
    false
  }
}
