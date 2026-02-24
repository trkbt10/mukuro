///|
/// Control Plane インターフェース
/// GatewayServiceを中心とした統合制御を提供する

///|
/// Gateway状態
pub(all) enum GatewayState {
  /// 停止中
  Stopped
  /// 起動中
  Starting
  /// 稼働中
  Running
  /// 停止処理中
  Stopping
  /// エラー状態
  Error(String)
}

///|
/// GatewayStateを文字列に変換
pub fn GatewayState::to_string(self : GatewayState) -> String {
  match self {
    GatewayState::Stopped => "stopped"
    GatewayState::Starting => "starting"
    GatewayState::Running => "running"
    GatewayState::Stopping => "stopping"
    GatewayState::Error(msg) => "error: \{msg}"
  }
}

///|
/// GatewayStateが稼働中かどうか
pub fn GatewayState::is_running(self : GatewayState) -> Bool {
  match self {
    GatewayState::Running => true
    _ => false
  }
}

///|
/// Gateway状態情報
pub(all) struct GatewayStatus {
  /// 現在の状態
  state : GatewayState
  /// ヘルス情報
  health : SystemHealth?
  /// 接続中のチャネル
  connected_channels : Array[String]
  /// アクティブセッション数
  active_sessions : Int
  /// 起動時刻（Unix epoch ミリ秒）
  started_at : Int64?
  /// バージョン
  version : String
}

///|
/// GatewayStatusを新規作成
pub fn GatewayStatus::new(
  state~ : GatewayState,
  health~ : SystemHealth?,
  connected_channels~ : Array[String],
  active_sessions~ : Int,
  started_at~ : Int64?,
  version~ : String,
) -> GatewayStatus {
  { state, health, connected_channels, active_sessions, started_at, version }
}

///|
/// 停止状態のGatewayStatus
pub fn GatewayStatus::stopped(version~ : String) -> GatewayStatus {
  {
    state: GatewayState::Stopped,
    health: None,
    connected_channels: [],
    active_sessions: 0,
    started_at: None,
    version,
  }
}

///|
/// 認証コンテキスト
pub(all) struct AuthContext {
  /// トークン
  token : String
  /// ユーザーID（オプション）
  user_id : String?
  /// 有効期限（Unix epoch ミリ秒、オプション）
  expires_at : Int64?
}

///|
/// AuthContextを新規作成
pub fn AuthContext::new(
  token~ : String,
  user_id~ : String?,
  expires_at~ : Int64?,
) -> AuthContext {
  { token, user_id, expires_at }
}

///|
/// トークンのみのAuthContext
pub fn AuthContext::token_only(token : String) -> AuthContext {
  { token, user_id: None, expires_at: None }
}

///|
/// 認証結果
pub(all) enum AuthResult {
  /// 認証成功
  Authenticated(AuthContext)
  /// 認証失敗
  Denied(String)
  /// トークン期限切れ
  Expired
}

///|
/// 認証エラー
pub(all) suberror AuthError {
  InvalidToken(String)
  TokenExpired
  Unauthorized(String)
}

///|
/// Control Planeエラー
pub(all) suberror ControlError {
  /// 認証エラー
  Auth(AuthError)
  /// 既に起動中
  AlreadyRunning
  /// 既に停止中
  AlreadyStopped
  /// 設定エラー
  ConfigError(String)
  /// チャネルエラー
  ChannelError(String)
  /// 内部エラー
  InternalError(String)
}

///|
/// 認証器 トレイト
pub(open) trait Authenticator {
  /// トークンを検証
  validate(Self, token~ : String) -> AuthResult
  /// トークンを発行（オプション）
  issue_token(Self, user_id~ : String) -> String raise AuthError
  /// トークンを無効化
  revoke(Self, token~ : String) -> Unit raise AuthError
}

///|
/// Gateway設定
pub(all) struct GatewayConfig {
  /// ホスト
  host : String
  /// ポート
  port : Int
  /// 認証トークン（空の場合は認証無効）
  auth_token : String
  /// ヘルスエンドポイント設定
  health_endpoint : HealthEndpointConfig
  /// 起動時に全チャネルに自動接続するか
  auto_connect_channels : Bool
}

///|
/// デフォルトのGateway設定
pub fn GatewayConfig::default() -> GatewayConfig {
  {
    host: "127.0.0.1",
    port: 8080,
    auth_token: "",
    health_endpoint: HealthEndpointConfig::default(),
    auto_connect_channels: true,
  }
}

///|
/// Gatewayサービス トレイト
/// チャネル受信からエージェント応答送信までの統合制御を提供
pub(open) trait GatewayService {
  /// Gatewayを起動
  start(Self, config~ : GatewayConfig) -> Unit raise ControlError
  /// Gatewayを停止
  stop(Self) -> Unit raise ControlError
  /// 状態を取得
  status(Self) -> GatewayStatus
  /// 認証を検証（操作前に呼び出す）
  authenticate(Self, token~ : String) -> AuthResult
  /// インバウンドメッセージをディスパッチ（認証済み操作）
  dispatch_inbound(
    Self,
    auth~ : AuthContext,
    envelope~ : @types.InboundEnvelope,
  ) -> Unit raise ControlError
  /// アウトバウンドメッセージをディスパッチ（認証済み操作）
  dispatch_outbound(
    Self,
    auth~ : AuthContext,
    message~ : @types.OutboundMessage,
  ) -> Unit raise ControlError
}

///|
/// イベントリスナー トレイト
/// Gateway内部のイベントを受け取る
pub(open) trait GatewayEventListener {
  /// Gateway状態変更
  on_state_change(Self, old~ : GatewayState, new~ : GatewayState) -> Unit
  /// メッセージ受信
  on_message_received(Self, envelope~ : @types.InboundEnvelope) -> Unit
  /// メッセージ送信
  on_message_sent(Self, message~ : @types.OutboundMessage) -> Unit
  /// エラー発生
  on_error(Self, error~ : String) -> Unit
}
