///|
/// チャネルアダプタ トレイト
/// 各チャネル（Discord, Slack等）との通信を抽象化する (async)
pub(open) trait ChannelAdapter {
  /// チャネル名を取得
  name(Self) -> String
  /// 接続 (async)
  async connect(Self) -> Unit
  /// 切断 (async)
  async disconnect(Self) -> Unit
  /// 接続中かどうか
  is_connected(Self) -> Bool
  /// メッセージを送信 (async)
  async send(Self, @types.OutboundMessage) -> Unit
  /// メッセージを受信 (async)
  async receive(Self) -> @types.InboundEnvelope
}

///|
/// チャネルマネージャ トレイト
/// 複数のチャネルを管理する (async)
pub(open) trait ChannelManager {
  /// チャネルを登録
  register(Self, &ChannelAdapter) -> Unit
  /// チャネル登録を解除
  unregister(Self, String) -> Unit
  /// チャネルを取得
  get_channel(Self, String) -> &ChannelAdapter?
  /// 全チャネル名のリスト
  list_channels(Self) -> Array[String]
  /// 全チャネルに接続 (async)
  async connect_all(Self) -> Unit
  /// 全チャネルから切断 (async)
  async disconnect_all(Self) -> Unit
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
