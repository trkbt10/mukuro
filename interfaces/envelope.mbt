///|
/// 出力配信トレイト
/// チャネルへメッセージを送信する (async)
pub(open) trait OutboundDispatcher {
  /// メッセージを送信 (async)
  async dispatch(Self, @types.OutboundMessage) -> Unit
}
