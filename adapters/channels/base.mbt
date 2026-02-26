///|
/// チャネルエラー
pub(all) suberror ChannelError {
  ConnectionFailed(String)
  AuthenticationFailed(String)
  RateLimited(retry_after~ : Int)
  MessageTooLong(max_length~ : Int)
  InvalidPayload(String)
  NetworkError(String)
  ChannelNotFound(String)
}

///|
/// チャネルの状態
pub(all) enum ChannelStatus {
  Connected
  Connecting
  Disconnected
  Reconnecting
  Error(String)
}

///|
/// チャネル共通設定
pub(all) struct ChannelBaseConfig {
  /// チャネル名
  name : String
  /// 有効かどうか
  enabled : Bool
  /// 再接続間隔（ミリ秒）
  reconnect_interval_ms : Int
  /// 最大再接続回数
  max_reconnect_attempts : Int
}

///|
/// デフォルト設定
pub fn ChannelBaseConfig::default(name~ : String) -> ChannelBaseConfig {
  {
    name,
    enabled: true,
    reconnect_interval_ms: 5000,
    max_reconnect_attempts: 10,
  }
}

///|
/// メッセージ送信結果
pub(all) struct SendResult {
  /// 送信成功かどうか
  success : Bool
  /// メッセージID（プラットフォーム固有）
  message_id : String?
  /// エラーメッセージ
  error : String?
}

///|
/// 送信成功
pub fn SendResult::success(message_id~ : String) -> SendResult {
  { success: true, message_id: Some(message_id), error: None }
}

///|
/// 送信失敗
pub fn SendResult::failure(error~ : String) -> SendResult {
  { success: false, message_id: None, error: Some(error) }
}

///|
/// チャネルメッセージハンドラ型
pub(all) struct MessageHandler {
  handler : (@types.InboundEnvelope) -> Unit
}

///|
/// チャネルイベントハンドラ型
pub(all) struct EventHandler {
  handler : (@interfaces.ChannelEvent) -> Unit
}

///|
/// ルーティングルール
pub(all) struct RoutingRule {
  /// ルール名
  name : String
  /// マッチ条件（チャネル名のパターン）
  channel_pattern : String
  /// マッチ条件（チャットIDのパターン、オプション）
  chat_pattern : String?
  /// ルーティング先セッションキー生成方法
  session_strategy : @session.SessionStrategy
}

///|
/// ルーティングルールを作成
pub fn RoutingRule::new(
  name~ : String,
  channel_pattern~ : String,
  chat_pattern~ : String?,
  session_strategy~ : @session.SessionStrategy,
) -> RoutingRule {
  { name, channel_pattern, chat_pattern, session_strategy }
}

///|
/// ルートリゾルバ
pub struct RouteResolver {
  /// ルーティングルール一覧
  rules : Array[RoutingRule]
  /// デフォルトセッション戦略
  default_strategy : @session.SessionStrategy
}

///|
/// RouteResolverを新規作成
pub fn RouteResolver::new(
  default_strategy~ : @session.SessionStrategy,
) -> RouteResolver {
  { rules: [], default_strategy }
}

///|
/// ルールを追加
pub fn RouteResolver::add_rule(
  self : RouteResolver,
  rule : RoutingRule,
) -> Unit {
  self.rules.push(rule)
}

///|
/// パターンがマッチするかチェック（単純な前方一致）
fn matches_pattern(value : String, pattern : String) -> Bool {
  if pattern == "*" {
    true
  } else if pattern.has_suffix("*") {
    let prefix = pattern.unsafe_substring(start=0, end=pattern.length() - 1)
    value.has_prefix(prefix)
  } else {
    value == pattern
  }
}

///|
/// エンベロープに対するセッション戦略を解決
pub fn RouteResolver::resolve(
  self : RouteResolver,
  envelope : @types.InboundEnvelope,
) -> @session.SessionStrategy {
  for rule in self.rules {
    // チャネルパターンをチェック
    if not(matches_pattern(envelope.channel, rule.channel_pattern)) {
      continue
    }
    // チャットパターンをチェック（指定されている場合）
    match rule.chat_pattern {
      Some(pattern) =>
        if not(matches_pattern(envelope.chat_id, pattern)) {
          continue
        }
      None => ()
    }
    // マッチしたルールの戦略を返す
    return rule.session_strategy
  }
  // デフォルト戦略を返す
  self.default_strategy
}

///|
/// チャネルマネージャ実装
pub struct ChannelManagerImpl {
  /// 登録済みチャネル
  channels : Map[String, &@interfaces.ChannelAdapter]
  /// ルートリゾルバ
  router : RouteResolver
  /// メッセージハンドラ
  mut message_handler : MessageHandler?
  /// イベントハンドラ
  mut event_handler : EventHandler?
}

///|
/// ChannelManagerImplを新規作成
pub fn ChannelManagerImpl::new(router~ : RouteResolver) -> ChannelManagerImpl {
  { channels: {}, router, message_handler: None, event_handler: None }
}

///|
/// メッセージハンドラを設定
pub fn ChannelManagerImpl::set_message_handler(
  self : ChannelManagerImpl,
  handler : MessageHandler,
) -> Unit {
  self.message_handler = Some(handler)
}

///|
/// イベントハンドラを設定
pub fn ChannelManagerImpl::set_event_handler(
  self : ChannelManagerImpl,
  handler : EventHandler,
) -> Unit {
  self.event_handler = Some(handler)
}

///|
/// ChannelManager実装
pub impl @interfaces.ChannelManager for ChannelManagerImpl with register(
  self,
  channel,
) {
  self.channels[channel.name()] = channel
}

///|
pub impl @interfaces.ChannelManager for ChannelManagerImpl with unregister(
  self,
  name,
) {
  self.channels.remove(name)
}

///|
pub impl @interfaces.ChannelManager for ChannelManagerImpl with get_channel(
  self,
  name,
) {
  self.channels.get(name)
}

///|
pub impl @interfaces.ChannelManager for ChannelManagerImpl with list_channels(
  self,
) {
  let result : Array[String] = []
  for name, _ in self.channels {
    result.push(name)
  }
  result
}

///|
pub impl @interfaces.ChannelManager for ChannelManagerImpl with connect_all(
  self,
) {
  for _, channel in self.channels {
    channel.connect()
  }
}

///|
pub impl @interfaces.ChannelManager for ChannelManagerImpl with disconnect_all(
  self,
) {
  for _, channel in self.channels {
    channel.disconnect()
  }
}

///|
/// 全チャネルにメッセージをブロードキャスト (async)
pub async fn ChannelManagerImpl::broadcast(
  self : ChannelManagerImpl,
  message : @types.OutboundMessage,
) -> Unit {
  for _, channel in self.channels {
    channel.send(message) catch {
      _ => () // エラーは無視
    }
  }
}
