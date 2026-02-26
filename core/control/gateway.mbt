///|
/// GatewayService実装
/// チャネル・セッション・エージェントループを統合する

///|
/// 時刻取得関数型
pub struct TimeProvider(() -> Int64)

///|
/// TimeProviderを生成
pub fn TimeProvider::new(provider~ : () -> Int64) -> TimeProvider {
  TimeProvider(provider)
}

///|
/// エージェント処理関数型
/// InboundEnvelope を受け取り、OutboundMessage を返す（または失敗）(async)
pub struct AgentHandler(
  async (@types.InboundEnvelope) -> @types.OutboundMessage raise
)

///|
/// AgentHandlerを生成
pub fn AgentHandler::new(
  handler~ : async (@types.InboundEnvelope) -> @types.OutboundMessage raise,
) -> AgentHandler {
  AgentHandler(handler)
}

///|
/// Gateway実装
pub struct Gateway {
  /// 現在の状態
  mut state : @interfaces.GatewayState
  /// 起動時刻
  mut started_at : Int64?
  /// 設定
  mut config : @interfaces.GatewayConfig?
  /// チャネルマネージャ
  channel_manager : &@interfaces.ChannelManager?
  /// セッションリゾルバ
  session_resolver : &@interfaces.SessionResolver?
  /// セッションストア
  session_store : &@interfaces.SessionStore?
  /// ヘルスアグリゲータ
  health_aggregator : &@interfaces.HealthAggregator?
  /// アウトバウンドディスパッチャー
  outbound_dispatcher : &@interfaces.OutboundDispatcher?
  /// イベントリスナー
  listeners : Array[&@interfaces.GatewayEventListener]
  /// バージョン
  version : String
  /// 時刻取得関数
  time_provider : TimeProvider?
  /// エージェント処理関数
  agent_handler : AgentHandler?
}

///|
/// Gateway依存関係
pub struct GatewayDependencies {
  channel_manager : &@interfaces.ChannelManager?
  session_resolver : &@interfaces.SessionResolver?
  session_store : &@interfaces.SessionStore?
  health_aggregator : &@interfaces.HealthAggregator?
  outbound_dispatcher : &@interfaces.OutboundDispatcher?
  time_provider : TimeProvider?
  agent_handler : AgentHandler?
}

///|
/// Gatewayを新規作成
pub fn Gateway::new(deps~ : GatewayDependencies, version~ : String) -> Gateway {
  {
    state: @interfaces.GatewayState::Stopped,
    started_at: None,
    config: None,
    channel_manager: deps.channel_manager,
    session_resolver: deps.session_resolver,
    session_store: deps.session_store,
    health_aggregator: deps.health_aggregator,
    outbound_dispatcher: deps.outbound_dispatcher,
    listeners: [],
    version,
    time_provider: deps.time_provider,
    agent_handler: deps.agent_handler,
  }
}

///|
/// 外部パッケージ向けの依存注入コンストラクタ
pub fn Gateway::with_components(
  channel_manager~ : &@interfaces.ChannelManager?,
  session_resolver~ : &@interfaces.SessionResolver?,
  session_store~ : &@interfaces.SessionStore?,
  health_aggregator~ : &@interfaces.HealthAggregator?,
  outbound_dispatcher~ : &@interfaces.OutboundDispatcher?,
  time_provider~ : TimeProvider?,
  agent_handler~ : AgentHandler?,
  version~ : String,
) -> Gateway {
  Gateway::new(
    deps={
      channel_manager,
      session_resolver,
      session_store,
      health_aggregator,
      outbound_dispatcher,
      time_provider,
      agent_handler,
    },
    version~,
  )
}

///|
/// 最小構成のGatewayを作成
pub fn Gateway::minimal(version~ : String) -> Gateway {
  {
    state: @interfaces.GatewayState::Stopped,
    started_at: None,
    config: None,
    channel_manager: None,
    session_resolver: None,
    session_store: None,
    health_aggregator: None,
    outbound_dispatcher: None,
    listeners: [],
    version,
    time_provider: None,
    agent_handler: None,
  }
}

///|
/// イベントリスナーを登録
pub fn Gateway::add_listener(
  self : Gateway,
  listener : &@interfaces.GatewayEventListener,
) -> Unit {
  self.listeners.push(listener)
}

///|
/// 状態変更を通知
fn Gateway::notify_state_change(
  self : Gateway,
  old : @interfaces.GatewayState,
  new : @interfaces.GatewayState,
) -> Unit {
  for listener in self.listeners {
    listener.on_state_change(old~, new~)
  }
}

///|
/// エラーを通知
fn Gateway::notify_error(self : Gateway, error : String) -> Unit {
  for listener in self.listeners {
    listener.on_error(error~)
  }
}

///|
/// トークン認証を実行
fn Gateway::validate_token(
  self : Gateway,
  token : String,
) -> @interfaces.AuthResult {
  match self.config {
    Some(cfg) =>
      // 空のauth_tokenは認証無効を意味する
      if cfg.auth_token.is_empty() {
        @interfaces.AuthResult::Authenticated(
          @interfaces.AuthContext::token_only(token),
        )
      } else if token == cfg.auth_token {
        @interfaces.AuthResult::Authenticated(
          @interfaces.AuthContext::token_only(token),
        )
      } else {
        @interfaces.AuthResult::Denied("Invalid token")
      }
    None =>
      // 設定がない場合は認証無効
      @interfaces.AuthResult::Authenticated(
        @interfaces.AuthContext::token_only(token),
      )
  }
}

///|
/// 認証コンテキストを検証
fn Gateway::verify_auth(
  self : Gateway,
  auth : @interfaces.AuthContext,
) -> Unit raise @interfaces.ControlError {
  match self.validate_token(auth.token) {
    @interfaces.AuthResult::Authenticated(_) => ()
    @interfaces.AuthResult::Denied(msg) =>
      raise @interfaces.ControlError::Auth(
        @interfaces.AuthError::InvalidToken(msg),
      )
    @interfaces.AuthResult::Expired =>
      raise @interfaces.ControlError::Auth(@interfaces.AuthError::TokenExpired)
  }
}

///|
/// アクティブセッション数を取得
fn Gateway::count_active_sessions(self : Gateway) -> Int {
  match self.session_store {
    Some(store) => {
      let keys = store.list_keys() catch { _ => [] }
      keys.length()
    }
    None => 0
  }
}

///|
/// 接続中チャネル名を取得
fn Gateway::get_connected_channels(self : Gateway) -> Array[String] {
  match self.channel_manager {
    Some(manager) => manager.list_channels()
    None => []
  }
}

///|
/// GatewayService実装
pub impl @interfaces.GatewayService for Gateway with start(self, config~) {
  // 既に起動中の場合はエラー
  if self.state.is_running() {
    raise @interfaces.ControlError::AlreadyRunning
  }
  // 状態を起動中に変更
  let old_state = self.state
  self.state = @interfaces.GatewayState::Starting
  self.notify_state_change(old_state, self.state)
  // 設定を保存
  self.config = Some(config)
  // チャネルに接続（auto_connect_channelsが有効な場合）
  if config.auto_connect_channels {
    match self.channel_manager {
      Some(manager) =>
        manager.connect_all() catch {
          e => {
            self.state = @interfaces.GatewayState::Error(e.to_string())
            self.notify_error(e.to_string())
            raise @interfaces.ControlError::ChannelError(e.to_string())
          }
        }
      None => ()
    }
  }
  // 起動完了 - 時刻取得（time_provider未設定時はNone）
  self.started_at = match self.time_provider {
    Some(provider) => Some(provider())
    None => None
  }
  let old_state2 = self.state
  self.state = @interfaces.GatewayState::Running
  self.notify_state_change(old_state2, self.state)
}

///|
pub impl @interfaces.GatewayService for Gateway with stop(self) {
  // 既に停止中の場合はエラー
  match self.state {
    @interfaces.GatewayState::Stopped =>
      raise @interfaces.ControlError::AlreadyStopped
    @interfaces.GatewayState::Stopping =>
      raise @interfaces.ControlError::AlreadyStopped
    _ => ()
  }
  // 状態を停止中に変更
  let old_state = self.state
  self.state = @interfaces.GatewayState::Stopping
  self.notify_state_change(old_state, self.state)
  // チャネルから切断
  match self.channel_manager {
    Some(manager) =>
      manager.disconnect_all() catch {
        e => self.notify_error(e.to_string())
        // 切断エラーは警告として扱い、停止は継続
      }
    None => ()
  }
  // 停止完了
  self.started_at = None
  self.config = None
  let old_state2 = self.state
  self.state = @interfaces.GatewayState::Stopped
  self.notify_state_change(old_state2, self.state)
}

///|
pub impl @interfaces.GatewayService for Gateway with status(self) {
  let health : @interfaces.SystemHealth? = match self.health_aggregator {
    Some(aggregator) => Some(aggregator.check_all())
    None => None
  }
  @interfaces.GatewayStatus::new(
    state=self.state,
    health~,
    connected_channels=self.get_connected_channels(),
    active_sessions=self.count_active_sessions(),
    started_at=self.started_at,
    version=self.version,
  )
}

///|
pub impl @interfaces.GatewayService for Gateway with authenticate(self, token~) {
  self.validate_token(token)
}

///|
pub impl @interfaces.GatewayService for Gateway with dispatch_inbound(
  self,
  auth~,
  envelope~,
) {
  // 認証を検証
  self.verify_auth(auth) catch {
    e => raise e
  }
  // 稼働中でない場合はエラー
  if !self.state.is_running() {
    raise @interfaces.ControlError::InternalError("Gateway is not running")
  }
  // メッセージ受信を通知
  for listener in self.listeners {
    listener.on_message_received(envelope~)
  }
  // エージェントハンドラを実行
  let handler = match self.agent_handler {
    Some(h) => h
    None =>
      raise @interfaces.ControlError::ConfigError("No agent handler configured")
  }
  let outbound = handler(envelope) catch {
    e =>
      raise @interfaces.ControlError::InternalError(
        "Agent handler failed: \{e}",
      )
  }
  // 結果をアウトバウンドディスパッチャーに送信
  let dispatcher = match self.outbound_dispatcher {
    Some(d) => d
    None =>
      raise @interfaces.ControlError::ChannelError(
        "No outbound dispatcher configured",
      )
  }
  dispatcher.dispatch(outbound) catch {
    e =>
      raise @interfaces.ControlError::ChannelError(
        "Failed to dispatch response: \{e}",
      )
  }
  // メッセージ送信を通知
  for listener in self.listeners {
    listener.on_message_sent(message=outbound)
  }
}

///|
pub impl @interfaces.GatewayService for Gateway with dispatch_outbound(
  self,
  auth~,
  message~,
) {
  // 認証を検証
  self.verify_auth(auth) catch {
    e => raise e
  }
  // 稼働中でない場合はエラー
  if !self.state.is_running() {
    raise @interfaces.ControlError::InternalError("Gateway is not running")
  }
  // アウトバウンドディスパッチャーにメッセージを送信
  match self.outbound_dispatcher {
    Some(dispatcher) =>
      dispatcher.dispatch(message) catch {
        e =>
          raise @interfaces.ControlError::ChannelError(
            "Failed to dispatch: \{e}",
          )
      }
    None =>
      raise @interfaces.ControlError::ChannelError("No outbound dispatcher")
  }
  // メッセージ送信を通知
  for listener in self.listeners {
    listener.on_message_sent(message~)
  }
}
