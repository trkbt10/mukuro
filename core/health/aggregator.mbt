///|
/// ヘルス集約実装

///|
/// ヘルス集約器実装
pub struct HealthAggregatorImpl {
  /// 登録済みチェッカー
  checkers : Map[String, &@interfaces.HealthChecker]
  /// 起動時刻（Unix epoch ミリ秒）
  start_time : Int64
  /// バージョン
  version : String
  /// 時計
  clock : &@interfaces.Clock
  /// キャッシュされた結果
  cached_results : Map[String, CachedHealthCheck]
  /// キャッシュ有効期間（ミリ秒）
  cache_ttl_ms : Int64
}

///|
/// キャッシュされたヘルスチェック
struct CachedHealthCheck {
  /// チェック結果
  check : @interfaces.HealthCheck
  /// キャッシュ時刻
  cached_at : Int64
}

///|
/// HealthAggregatorImplを新規作成
pub fn HealthAggregatorImpl::new(
  version~ : String,
  clock~ : &@interfaces.Clock,
  cache_ttl_ms~ : Int64,
) -> HealthAggregatorImpl {
  {
    checkers: Map::new(),
    start_time: clock.now_ms(),
    version,
    clock,
    cached_results: Map::new(),
    cache_ttl_ms,
  }
}

///|
/// デフォルト設定で作成
pub fn HealthAggregatorImpl::with_defaults(
  clock~ : &@interfaces.Clock,
) -> HealthAggregatorImpl {
  {
    checkers: Map::new(),
    start_time: clock.now_ms(),
    version: "0.1.0",
    clock,
    cached_results: Map::new(),
    cache_ttl_ms: 5000L, // 5秒
  }
}

///|
/// キャッシュされた結果を取得（有効期限内であれば）
fn HealthAggregatorImpl::get_cached_check(
  self : HealthAggregatorImpl,
  name : String,
) -> @interfaces.HealthCheck? {
  match self.cached_results.get(name) {
    Some(cached) => {
      let now = self.clock.now_ms()
      if now - cached.cached_at < self.cache_ttl_ms {
        Some(cached.check)
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// チェック結果をキャッシュ
fn HealthAggregatorImpl::cache_check(
  self : HealthAggregatorImpl,
  check : @interfaces.HealthCheck,
) -> Unit {
  let cached_at = self.clock.now_ms()
  self.cached_results[check.name] = { check, cached_at }
}

///|
/// HealthAggregator実装
pub impl @interfaces.HealthAggregator for HealthAggregatorImpl with register(
  self,
  checker~,
) {
  self.checkers[checker.name()] = checker
}

///|
pub impl @interfaces.HealthAggregator for HealthAggregatorImpl with unregister(
  self,
  name~,
) {
  self.checkers.remove(name)
  self.cached_results.remove(name)
}

///|
pub impl @interfaces.HealthAggregator for HealthAggregatorImpl with check_all(
  self,
) {
  let now = self.clock.now_ms()
  let uptime = now - self.start_time
  let checks : Array[@interfaces.HealthCheck] = []
  for name, checker in self.checkers {
    // キャッシュをチェック
    let check = match self.get_cached_check(name) {
      Some(cached) => cached
      None => {
        let result = checker.check()
        self.cache_check(result)
        result
      }
    }
    checks.push(check)
  }
  @interfaces.SystemHealth::new(
    checks~,
    uptime_ms=uptime,
    version=self.version,
    checked_at=now,
  )
}

///|
pub impl @interfaces.HealthAggregator for HealthAggregatorImpl with check_all_async(
  self,
  on_complete~,
) {
  // 非同期バージョン - 実際には各チェッカーの check_async を呼び出す必要があるが
  // シンプルな実装では同期版を呼び出す
  let result = self.check_all()
  on_complete(result)
}

///|
pub impl @interfaces.HealthAggregator for HealthAggregatorImpl with get_check(
  self,
  name~,
) {
  match self.checkers.get(name) {
    Some(checker) =>
      match self.get_cached_check(name) {
        Some(cached) => Some(cached)
        None => {
          let result = checker.check()
          self.cache_check(result)
          Some(result)
        }
      }
    None => None
  }
}

///|
pub impl @interfaces.HealthAggregator for HealthAggregatorImpl with list_checkers(
  self,
) {
  let names : Array[String] = []
  for name, _ in self.checkers {
    names.push(name)
  }
  names
}

///|
/// 常に正常を返すシンプルなチェッカー（Liveness用）
pub struct AlwaysHealthyChecker {
  /// チェッカー名
  checker_name : String
}

///|
/// AlwaysHealthyCheckerを新規作成
pub fn AlwaysHealthyChecker::new(name~ : String) -> AlwaysHealthyChecker {
  { checker_name: name }
}

///|
/// HealthChecker実装
pub impl @interfaces.HealthChecker for AlwaysHealthyChecker with name(self) {
  self.checker_name
}

///|
pub impl @interfaces.HealthChecker for AlwaysHealthyChecker with check(self) {
  @interfaces.HealthCheck::healthy(
    name=self.checker_name,
    latency_ms=Some(0L),
    last_check=0L, // 時計がないのでダミー
  )
}

///|
pub impl @interfaces.HealthChecker for AlwaysHealthyChecker with check_async(
  self,
  on_complete~,
) {
  on_complete(self.check())
}

///|
/// HTTP接続チェッカー
pub struct HttpHealthChecker {
  /// チェッカー名
  checker_name : String
  /// チェック先URL
  url : String
  /// タイムアウト（ミリ秒）
  timeout_ms : Int64
  /// HTTPクライアント
  http_client : &@interfaces.HttpClient
  /// 時計
  clock : &@interfaces.Clock
}

///|
/// HttpHealthCheckerを新規作成
pub fn HttpHealthChecker::new(
  name~ : String,
  url~ : String,
  timeout_ms~ : Int64,
  http_client~ : &@interfaces.HttpClient,
  clock~ : &@interfaces.Clock,
) -> HttpHealthChecker {
  { checker_name: name, url, timeout_ms, http_client, clock }
}

///|
/// HealthChecker実装
pub impl @interfaces.HealthChecker for HttpHealthChecker with name(self) {
  self.checker_name
}

///|
pub impl @interfaces.HealthChecker for HttpHealthChecker with check(self) {
  let start = self.clock.now_ms()
  let result = self.http_client.get(url=self.url, headers=Map::new()) catch {
    e => {
      let latency = self.clock.now_ms() - start
      return @interfaces.HealthCheck::unhealthy(
        name=self.checker_name,
        message=e.to_string(),
        latency_ms=Some(latency),
        last_check=start,
      )
    }
  }
  let latency = self.clock.now_ms() - start
  ignore(self.timeout_ms)
  if result.status >= 200 && result.status < 300 {
    @interfaces.HealthCheck::healthy(
      name=self.checker_name,
      latency_ms=Some(latency),
      last_check=start,
    )
  } else if result.status >= 500 {
    @interfaces.HealthCheck::unhealthy(
      name=self.checker_name,
      message="HTTP \{result.status}",
      latency_ms=Some(latency),
      last_check=start,
    )
  } else {
    @interfaces.HealthCheck::degraded(
      name=self.checker_name,
      message="HTTP \{result.status}",
      latency_ms=Some(latency),
      last_check=start,
    )
  }
}

///|
pub impl @interfaces.HealthChecker for HttpHealthChecker with check_async(
  self,
  on_complete~,
) {
  // シンプルな実装では同期版を呼び出す
  on_complete(self.check())
}

///|
/// メモリ使用量チェッカー（スタブ）
pub struct MemoryHealthChecker {
  /// チェッカー名
  checker_name : String
  /// 警告閾値（パーセント）
  warn_threshold_percent : Int
  /// エラー閾値（パーセント）
  error_threshold_percent : Int
}

///|
/// MemoryHealthCheckerを新規作成
pub fn MemoryHealthChecker::new(
  name~ : String,
  warn_threshold_percent~ : Int,
  error_threshold_percent~ : Int,
) -> MemoryHealthChecker {
  { checker_name: name, warn_threshold_percent, error_threshold_percent }
}

///|
/// デフォルト設定で作成
pub fn MemoryHealthChecker::default() -> MemoryHealthChecker {
  {
    checker_name: "memory",
    warn_threshold_percent: 80,
    error_threshold_percent: 95,
  }
}

///|
/// HealthChecker実装
pub impl @interfaces.HealthChecker for MemoryHealthChecker with name(self) {
  self.checker_name
}

///|
pub impl @interfaces.HealthChecker for MemoryHealthChecker with check(self) {
  // メモリ情報取得はプラットフォーム固有のため、スタブとして常に正常を返す
  ignore(self.warn_threshold_percent)
  ignore(self.error_threshold_percent)
  @interfaces.HealthCheck::healthy(
    name=self.checker_name,
    latency_ms=Some(0L),
    last_check=0L,
  )
}

///|
pub impl @interfaces.HealthChecker for MemoryHealthChecker with check_async(
  self,
  on_complete~,
) {
  on_complete(self.check())
}

///|
/// コールバック付きカスタムチェッカー
pub struct CallbackHealthChecker {
  /// チェッカー名
  checker_name : String
  /// チェック関数
  check_fn : () -> @interfaces.HealthCheck
}

///|
/// CallbackHealthCheckerを新規作成
pub fn CallbackHealthChecker::new(
  name~ : String,
  check_fn~ : () -> @interfaces.HealthCheck,
) -> CallbackHealthChecker {
  { checker_name: name, check_fn }
}

///|
/// HealthChecker実装
pub impl @interfaces.HealthChecker for CallbackHealthChecker with name(self) {
  self.checker_name
}

///|
pub impl @interfaces.HealthChecker for CallbackHealthChecker with check(self) {
  (self.check_fn)()
}

///|
pub impl @interfaces.HealthChecker for CallbackHealthChecker with check_async(
  self,
  on_complete~,
) {
  on_complete(self.check())
}
