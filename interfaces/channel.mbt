///|
/// チャネルアダプタ トレイト
/// 各チャネル（Discord, Slack等）との通信を抽象化する
pub(open) trait ChannelAdapter {
  /// チャネル名を取得
  name(Self) -> String
  /// 接続
  connect(Self) -> Unit raise
  /// 切断
  disconnect(Self) -> Unit raise
  /// 接続中かどうか
  is_connected(Self) -> Bool
  /// メッセージを送信
  send(Self, @types.OutboundMessage) -> Unit raise
  /// メッセージを受信（ブロッキング）
  receive(Self) -> @types.InboundEnvelope raise
}

///|
/// チャネルマネージャ トレイト
/// 複数のチャネルを管理する
pub(open) trait ChannelManager {
  /// チャネルを登録
  register(Self, &ChannelAdapter) -> Unit
  /// チャネル登録を解除
  unregister(Self, String) -> Unit
  /// チャネルを取得
  get_channel(Self, String) -> &ChannelAdapter?
  /// 全チャネル名のリスト
  list_channels(Self) -> Array[String]
  /// 全チャネルに接続
  connect_all(Self) -> Unit raise
  /// 全チャネルから切断
  disconnect_all(Self) -> Unit raise
}

///|
/// チャネルイベント
pub(all) enum ChannelEvent {
  /// メッセージ受信
  MessageReceived(@types.InboundEnvelope)
  /// 接続確立
  Connected(channel~ : String)
  /// 切断
  Disconnected(channel~ : String)
  /// エラー
  Error(channel~ : String, message~ : String)
}
