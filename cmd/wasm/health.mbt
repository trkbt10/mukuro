///|
/// Health Endpoint Implementation
/// HTTPヘルスチェックエンドポイント

///|
/// グローバルヘルスアグリゲータ
let health_aggregator : HealthManager = HealthManager::new()

///|
/// ヘルスマネージャー（遅延初期化対応）
struct HealthManager {
  mut aggregator : @health.HealthAggregatorImpl?
  mut clock : JsClock?
}

///|
/// ヘルスマネージャーを作成
fn HealthManager::new() -> HealthManager {
  { aggregator: None, clock: None }
}

///|
/// アグリゲータを初期化
fn HealthManager::init(self : HealthManager) -> @health.HealthAggregatorImpl {
  match self.aggregator {
    Some(agg) => agg
    None => {
      let clock = JsClock::new()
      self.clock = Some(clock)
      let agg = @health.HealthAggregatorImpl::with_defaults(clock~)
      // デフォルトのチェッカーを登録
      agg.register(checker=@health.AlwaysHealthyChecker::new(name="liveness"))
      // 初期化状態チェッカーを登録
      agg.register(checker=InitializationChecker::new())
      self.aggregator = Some(agg)
      agg
    }
  }
}

///|
/// JavaScript時計実装
struct JsClock {
  // 空のstructなのでダミーフィールドを追加
  _dummy : Unit
}

///|
fn JsClock::new() -> JsClock {
  { _dummy: () }
}

///|
pub impl @interfaces.Clock for JsClock with now_ms(self) {
  ignore(self)
  @js.js_date_now()
}

///|
pub impl @interfaces.Clock for JsClock with now_seconds(self) {
  ignore(self)
  @js.js_date_now() / 1000L
}

///|
/// 初期化状態チェッカー
struct InitializationChecker {
  // 空のstructなのでダミーフィールドを追加
  _dummy : Unit
}

///|
fn InitializationChecker::new() -> InitializationChecker {
  { _dummy: () }
}

///|
pub impl @interfaces.HealthChecker for InitializationChecker with name(self) {
  ignore(self)
  "initialization"
}

///|
pub impl @interfaces.HealthChecker for InitializationChecker with check(self) {
  ignore(self)
  let now = @js.js_date_now()
  if global_config.initialized {
    @interfaces.HealthCheck::healthy(
      name="initialization",
      latency_ms=Some(0L),
      last_check=now,
    )
  } else {
    @interfaces.HealthCheck::degraded(
      name="initialization",
      message="Agent not initialized",
      latency_ms=Some(0L),
      last_check=now,
    )
  }
}

///|
/// フルヘルスチェック（/health）
/// すべてのチェッカーを実行し、詳細な結果を返す
pub async fn health_full() -> String {
  let aggregator = health_aggregator.init()
  let health = aggregator.check_all()
  // JSON形式で出力
  let checks_json : Array[Json] = health.checks.map(fn(check) {
    {
      "name": check.name,
      "status": check.status.to_string(),
      "latency_ms": match check.latency_ms {
        Some(ms) => Number(ms.to_double(), repr=None)
        None => Null
      },
      "last_check": Number(check.last_check.to_double(), repr=None),
    }
  })
  let result : Json = {
    "overall": health.overall.to_string(),
    "checks": Json::array(checks_json),
    "uptime_ms": Number(health.uptime_ms.to_double(), repr=None),
    "version": health.version,
    "checked_at": Number(health.checked_at.to_double(), repr=None),
  }
  result.stringify()
}

///|
/// ライブネスチェック（/health/live）
/// シンプルな生存確認のみ
pub async fn health_live() -> String {
  let aggregator = health_aggregator.init()
  let health = aggregator.check_all()
  let mut status = "unknown"
  for check in health.checks {
    if check.name == "liveness" {
      status = check.status.to_string()
      break
    }
  }
  let result : Json = { "status": status }
  result.stringify()
}

///|
/// レディネスチェック（/health/ready）
/// アプリケーションがリクエストを処理できる状態かどうか
pub async fn health_ready() -> String {
  let aggregator = health_aggregator.init()
  let health = aggregator.check_all()
  // 全てのチェックが正常であればready
  let is_ready = health.overall.is_healthy()
  let result : Json = {
    "ready": is_ready,
    "status": health.overall.to_string(),
    "version": health.version,
  }
  result.stringify()
}

///|
/// カスタムヘルスチェッカーを登録
pub fn register_health_checker(
  name : String,
  check_fn : () -> Bool,
  message_on_fail : String,
) -> Unit {
  let aggregator = health_aggregator.init()
  let checker = @health.CallbackHealthChecker::new(name~, check_fn=fn() {
    let now = @js.js_date_now()
    if check_fn() {
      @interfaces.HealthCheck::healthy(
        name~,
        latency_ms=Some(0L),
        last_check=now,
      )
    } else {
      @interfaces.HealthCheck::unhealthy(
        name~,
        message=message_on_fail,
        latency_ms=Some(0L),
        last_check=now,
      )
    }
  })
  aggregator.register(checker~)
}

///|
/// ヘルスチェッカーを削除
pub fn unregister_health_checker(name : String) -> Unit {
  let aggregator = health_aggregator.init()
  aggregator.unregister(name~)
}

///|
/// 登録済みヘルスチェッカー一覧を取得
pub fn list_health_checkers() -> String {
  let aggregator = health_aggregator.init()
  let names = aggregator.list_checkers()
  let names_json : Array[Json] = names.map(fn(n) { Json::string(n) })
  Json::array(names_json).stringify()
}
