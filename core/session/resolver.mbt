///|
/// セッション解決ストラテジー
pub(all) enum SessionStrategy {
  /// チャネル＋チャットIDでセッションを識別（デフォルト）
  PerChat
  /// チャネル＋チャットID＋ユーザーIDでセッションを識別
  PerUser
  /// 優先スコープ（peer/guild/team/account/channel/chat）でセッションを識別
  PerRoutingScope
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
    SessionStrategy::PerRoutingScope =>
      @types.SessionKey::new(
        channel=envelope.channel,
        chat_id=resolve_routing_scope_chat_id(envelope),
        user_id=None,
      )
    SessionStrategy::Custom(f) => f(envelope)
  }
}

///|
fn metadata_string(metadata : Map[String, Json], key : String) -> String? {
  match metadata.get(key) {
    Some(String(v)) => if v.length() > 0 { Some(v) } else { None }
    _ => None
  }
}

///|
fn resolve_routing_scope_chat_id(envelope : @types.InboundEnvelope) -> String {
  let metadata = envelope.metadata
  match metadata_string(metadata, "peer_id") {
    Some(id) => return "peer-\{id}"
    None => ()
  }
  match metadata_string(metadata, "guild_id") {
    Some(id) => return "guild-\{id}"
    None => ()
  }
  match metadata_string(metadata, "team_id") {
    Some(id) => return "team-\{id}"
    None => ()
  }
  match metadata_string(metadata, "account_id") {
    Some(id) => return "account-\{id}"
    None => ()
  }
  match metadata_string(metadata, "channel_id") {
    Some(id) => return "channel-\{id}"
    None => ()
  }
  envelope.chat_id
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
  let parts = storage_key.split(":")
  let parts_arr : Array[String] = parts.map(fn(sv) { sv.to_string() }).collect()
  match parts_arr.length() {
    3 =>
      if parts_arr[0] != "session" {
        None
      } else {
        Some(
          @types.SessionKey::new(
            channel=parts_arr[1],
            chat_id=parts_arr[2],
            user_id=None,
          ),
        )
      }
    4 =>
      if parts_arr[0] != "session" {
        None
      } else {
        Some(
          @types.SessionKey::new(
            channel=parts_arr[1],
            chat_id=parts_arr[2],
            user_id=Some(parts_arr[3]),
          ),
        )
      }
    _ => None
  }
}
