///|
/// セッション解決ストラテジー
pub(all) enum SessionStrategy {
  /// チャネル＋チャットIDでセッションを識別（デフォルト）
  PerChat
  /// チャネル＋チャットID＋ユーザーIDでセッションを識別
  PerUser
  /// カスタムキー生成関数
  Custom((@types.InboundEnvelope) -> @types.SessionKey)
}

///|
/// 設定可能なセッション解決器
pub struct ConfigurableSessionResolver {
  strategy : SessionStrategy
}

///|
/// ConfigurableSessionResolverを新規作成
pub fn ConfigurableSessionResolver::new(
  strategy~ : SessionStrategy,
) -> ConfigurableSessionResolver {
  { strategy, }
}

///|
/// デフォルトのセッション解決器（PerChat戦略）
pub fn ConfigurableSessionResolver::default() -> ConfigurableSessionResolver {
  { strategy: SessionStrategy::PerChat }
}

///|
/// SessionResolver実装
pub impl @interfaces.SessionResolver for ConfigurableSessionResolver with resolve(
  self,
  envelope,
) {
  match self.strategy {
    SessionStrategy::PerChat =>
      @types.SessionKey::new(
        channel=envelope.channel,
        chat_id=envelope.chat_id,
        user_id=None,
      )
    SessionStrategy::PerUser =>
      @types.SessionKey::new(
        channel=envelope.channel,
        chat_id=envelope.chat_id,
        user_id=Some(envelope.sender_id),
      )
    SessionStrategy::Custom(f) => f(envelope)
  }
}

///|
/// セッションキーからストレージキーを生成
pub fn session_key_to_storage_key(key : @types.SessionKey) -> String {
  "session:\{key.to_string()}"
}

///|
/// ストレージキーからセッションキーをパース
pub fn parse_session_key(storage_key : String) -> @types.SessionKey? {
  // "session:channel:chat_id" or "session:channel:chat_id:user_id"
  let prefix = "session:"
  if not(storage_key.has_prefix(prefix)) {
    return None
  }
  // プレフィックス除去
  let key_part = storage_key
    .iter()
    .drop(prefix.length())
    .fold(init=StringBuilder::new(), fn(sb, c) {
      sb.write_char(c)
      sb
    })
    .to_string()
  let parts = key_part.split(":")
  let parts_arr : Array[String] = parts.map(fn(sv) { sv.to_string() }).collect()
  match parts_arr.length() {
    2 =>
      Some(
        @types.SessionKey::new(
          channel=parts_arr[0],
          chat_id=parts_arr[1],
          user_id=None,
        ),
      )
    3 =>
      Some(
        @types.SessionKey::new(
          channel=parts_arr[0],
          chat_id=parts_arr[1],
          user_id=Some(parts_arr[2]),
        ),
      )
    _ => None
  }
}
