///|
/// セッション解決トレイト
/// InboundEnvelopeからセッションキーを導出する
pub(open) trait SessionResolver {
  /// セッションキーを解決
  resolve(Self, @types.InboundEnvelope) -> @types.SessionKey
}

///|
/// セッションストアトレイト
/// セッションの永続化を担当する
pub(open) trait SessionStore {
  /// セッション取得
  get(Self, @types.SessionKey) -> @types.Session? raise
  /// セッション保存
  save(Self, @types.Session) -> Unit raise
  /// セッション削除
  delete(Self, @types.SessionKey) -> Unit raise
  /// 全セッションキーのリスト
  list_keys(Self) -> Array[@types.SessionKey] raise
}

///|
/// デフォルトのセッション解決器
/// channel:chat_id の形式でセッションキーを導出
pub struct DefaultSessionResolver {
  /// プレースホルダ（空構造体は許可されないため）
  _placeholder : Unit
}

///|
/// DefaultSessionResolverを新規作成
pub fn DefaultSessionResolver::new() -> DefaultSessionResolver {
  { _placeholder: () }
}

///|
/// DefaultSessionResolverのSessionResolver実装
pub impl SessionResolver for DefaultSessionResolver with resolve(
  _self,
  envelope,
) {
  @types.SessionKey::new(
    channel=envelope.channel,
    chat_id=envelope.chat_id,
    user_id=None,
  )
}
