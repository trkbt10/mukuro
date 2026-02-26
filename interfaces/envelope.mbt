///|
/// 出力配信トレイト
/// チャネルへメッセージを送信する (async)
pub(open) trait OutboundDispatcher {
  /// メッセージを送信 (async)
  async dispatch(Self, @types.OutboundMessage) -> Unit raise
}

///|
/// 入力受信トレイト
/// チャネルからメッセージを受信する
pub(open) trait InboundReceiver {
  /// 次のメッセージを受信（ブロッキング）
  receive(Self) -> @types.InboundEnvelope raise
  /// 次のメッセージを受信（タイムアウト付き）
  receive_timeout(Self, timeout_ms~ : Int64) -> @types.InboundEnvelope? raise
}
