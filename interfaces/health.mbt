///|
/// ヘルスチェックインターフェース

///|
/// ヘルスステータス
pub(all) enum HealthStatus {
  /// 正常
  Healthy
  /// 劣化状態（一部機能に問題）
  Degraded(String)
  /// 異常
  Unhealthy(String)
}

///|
/// HealthStatusを文字列に変換
pub fn HealthStatus::to_string(self : HealthStatus) -> String {
  match self {
    HealthStatus::Healthy => "healthy"
    HealthStatus::Degraded(msg) => "degraded: \{msg}"
    HealthStatus::Unhealthy(msg) => "unhealthy: \{msg}"
  }
}

///|
/// HealthStatusが正常かどうか
pub fn HealthStatus::is_healthy(self : HealthStatus) -> Bool {
  match self {
    HealthStatus::Healthy => true
    _ => false
  }
}

///|
/// HealthStatusが異常かどうか
pub fn HealthStatus::is_unhealthy(self : HealthStatus) -> Bool {
  match self {
    HealthStatus::Unhealthy(_) => true
    _ => false
  }
}

///|
/// 個別のヘルスチェック結果
pub(all) struct HealthCheck {
  /// チェッカー名
  name : String
  /// ステータス
  status : HealthStatus
  /// レイテンシ（ミリ秒、オプション）
  latency_ms : Int64?
  /// 最終チェック時刻（Unix epoch ミリ秒）
  last_check : Int64
  /// 追加情報
  details : Map[String, String]
}

///|
/// 正常なHealthCheckを作成
pub fn HealthCheck::healthy(
  name~ : String,
  latency_ms~ : Int64?,
  last_check~ : Int64,
) -> HealthCheck {
  {
    name,
    status: HealthStatus::Healthy,
    latency_ms,
    last_check,
    details: Map::new(),
  }
}

///|
/// 劣化状態のHealthCheckを作成
pub fn HealthCheck::degraded(
  name~ : String,
  message~ : String,
  latency_ms~ : Int64?,
  last_check~ : Int64,
) -> HealthCheck {
  {
    name,
    status: HealthStatus::Degraded(message),
    latency_ms,
    last_check,
    details: Map::new(),
  }
}

///|
/// 異常なHealthCheckを作成
pub fn HealthCheck::unhealthy(
  name~ : String,
  message~ : String,
  latency_ms~ : Int64?,
  last_check~ : Int64,
) -> HealthCheck {
  {
    name,
    status: HealthStatus::Unhealthy(message),
    latency_ms,
    last_check,
    details: Map::new(),
  }
}

///|
/// システム全体のヘルス状態
pub(all) struct SystemHealth {
  /// 全体ステータス
  overall : HealthStatus
  /// 個別チェック結果
  checks : Array[HealthCheck]
  /// 起動からの経過時間（ミリ秒）
  uptime_ms : Int64
  /// バージョン
  version : String
  /// チェック実行時刻
  checked_at : Int64
}

///|
/// SystemHealthを新規作成
pub fn SystemHealth::new(
  checks~ : Array[HealthCheck],
  uptime_ms~ : Int64,
  version~ : String,
  checked_at~ : Int64,
) -> SystemHealth {
  // 全体ステータスを計算
  let overall = calculate_overall_status(checks)
  { overall, checks, uptime_ms, version, checked_at }
}

///|
/// 全体ステータスを計算
fn calculate_overall_status(checks : Array[HealthCheck]) -> HealthStatus {
  let mut has_unhealthy = false
  let mut has_degraded = false
  let mut unhealthy_msg = ""
  let mut degraded_msg = ""
  for check in checks {
    match check.status {
      HealthStatus::Unhealthy(msg) => {
        has_unhealthy = true
        unhealthy_msg = if unhealthy_msg.is_empty() {
          "\{check.name}: \{msg}"
        } else {
          "\{unhealthy_msg}; \{check.name}: \{msg}"
        }
      }
      HealthStatus::Degraded(msg) => {
        has_degraded = true
        degraded_msg = if degraded_msg.is_empty() {
          "\{check.name}: \{msg}"
        } else {
          "\{degraded_msg}; \{check.name}: \{msg}"
        }
      }
      HealthStatus::Healthy => ()
    }
  }
  if has_unhealthy {
    HealthStatus::Unhealthy(unhealthy_msg)
  } else if has_degraded {
    HealthStatus::Degraded(degraded_msg)
  } else {
    HealthStatus::Healthy
  }
}

///|
/// ヘルスチェッカー トレイト
/// 個別のコンポーネントのヘルスを確認する
pub(open) trait HealthChecker {
  /// チェッカー名を取得
  name(Self) -> String
  /// ヘルスチェックを実行
  check(Self) -> HealthCheck
  /// 非同期ヘルスチェックを実行
  check_async(Self, on_complete~ : (HealthCheck) -> Unit) -> Unit
}

///|
/// ヘルス集約 トレイト
/// 複数のチェッカーを管理し、全体のヘルス状態を提供する
pub(open) trait HealthAggregator {
  /// チェッカーを登録
  register(Self, checker~ : &HealthChecker) -> Unit
  /// チェッカーを登録解除
  unregister(Self, name~ : String) -> Unit
  /// 全チェッカーを実行して結果を取得
  check_all(Self) -> SystemHealth
  /// 非同期で全チェッカーを実行
  check_all_async(Self, on_complete~ : (SystemHealth) -> Unit) -> Unit
  /// 特定のチェッカーの結果を取得
  get_check(Self, name~ : String) -> HealthCheck?
  /// 登録済みチェッカー名一覧を取得
  list_checkers(Self) -> Array[String]
}

///|
/// ヘルスエンドポイント設定
pub(all) struct HealthEndpointConfig {
  /// エンドポイントパス
  path : String
  /// 認証が必要か
  require_auth : Bool
  /// 詳細情報を含めるか
  include_details : Bool
  /// キャッシュ時間（秒）
  cache_seconds : Int
}

///|
/// デフォルトのヘルスエンドポイント設定
pub fn HealthEndpointConfig::default() -> HealthEndpointConfig {
  {
    path: "/health",
    require_auth: false,
    include_details: true,
    cache_seconds: 5,
  }
}

///|
/// Livenessエンドポイント用の設定
pub fn HealthEndpointConfig::liveness() -> HealthEndpointConfig {
  {
    path: "/health/live",
    require_auth: false,
    include_details: false,
    cache_seconds: 1,
  }
}

///|
/// Readinessエンドポイント用の設定
pub fn HealthEndpointConfig::readiness() -> HealthEndpointConfig {
  {
    path: "/health/ready",
    require_auth: false,
    include_details: true,
    cache_seconds: 5,
  }
}
