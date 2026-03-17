///|
/// セッションキー（複合キー）
pub(all) struct SessionKey {
  /// チャネル識別子
  channel : String
  /// チャット/スレッド識別子
  chat_id : String
  /// ユーザーID（オプション: ユーザー固有セッションの場合）
  user_id : String?
} derive(Eq, Hash, Show)

///|
/// セッション状態
pub(all) enum SessionState {
  /// アクティブ
  Active
  /// 一時停止
  Paused
  /// 終了
  Ended
} derive(Show)

///|
/// セッション
pub(all) struct Session {
  /// セッションキー
  key : SessionKey
  /// 会話履歴
  history : Array[@llm_types.ModelMessage]
  /// セッション状態
  state : SessionState
  /// セッション開始時刻（Unix epoch ms）
  created_at : Int64
  /// 最終アクティブ時刻（Unix epoch ms）
  last_active_at : Int64
  /// カスタムメタデータ
  metadata : Map[String, Json]
}

///|
/// SessionKeyを新規作成
pub fn SessionKey::new(
  channel~ : String,
  chat_id~ : String,
  user_id~ : String?,
) -> SessionKey {
  { channel, chat_id, user_id }
}

///|
/// SessionKeyを文字列表現に変換
pub fn SessionKey::to_string(self : SessionKey) -> String {
  match self.user_id {
    Some(uid) => "\{self.channel}:\{self.chat_id}:\{uid}"
    None => "\{self.channel}:\{self.chat_id}"
  }
}

///|
/// Sessionを新規作成
pub fn Session::new(key : SessionKey, now : Int64) -> Session {
  {
    key,
    history: [],
    state: SessionState::Active,
    created_at: now,
    last_active_at: now,
    metadata: {},
  }
}

///|
/// セッションにメッセージを追加
pub fn Session::add_message(self : Session, message : @llm_types.ModelMessage) -> Unit {
  self.history.push(message)
}

///|
/// セッションの最終アクティブ時刻を更新（新しいSessionを返す）
pub fn Session::touch(self : Session, now : Int64) -> Session {
  {
    key: self.key,
    history: self.history,
    state: self.state,
    created_at: self.created_at,
    last_active_at: now,
    metadata: self.metadata,
  }
}
