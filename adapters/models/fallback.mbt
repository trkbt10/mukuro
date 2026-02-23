///|
/// フォールバックオーケストレータ設定
pub(all) struct FallbackConfig {
  /// 有効かどうか
  enabled : Bool
  /// フォールバック間のクールダウン（ミリ秒）
  cooldown_ms : Int64
  /// 最大リトライ回数
  max_retries : Int
}

///|
/// デフォルト設定
pub fn FallbackConfig::default() -> FallbackConfig {
  { enabled: true, cooldown_ms: 5000L, max_retries: 3 }
}

///|
/// プロバイダの状態
pub(all) struct ProviderState {
  /// 最後のエラー時刻（Unix epoch ms）
  last_error_at : Int64
  /// 連続エラー回数
  error_count : Int
  /// 利用可能かどうか
  available : Bool
}

///|
/// 新しいProviderStateを作成
pub fn ProviderState::new() -> ProviderState {
  { last_error_at: 0L, error_count: 0, available: true }
}

///|
/// フォールバックオーケストレータ
/// 複数のプロバイダを管理し、失敗時にフォールバックする
pub struct FallbackOrchestrator {
  /// プロバイダリスト
  providers : Array[&@interfaces.ModelProvider]
  /// 各プロバイダの状態
  states : Map[String, ProviderState]
  /// 設定
  config : FallbackConfig
}

///|
/// FallbackOrchestratorを新規作成
pub fn FallbackOrchestrator::new(
  providers~ : Array[&@interfaces.ModelProvider],
  config~ : FallbackConfig,
) -> FallbackOrchestrator {
  let states : Map[String, ProviderState] = {}
  for provider in providers {
    states[provider.name()] = ProviderState::new()
  }
  { providers, states, config }
}

///|
/// プロバイダを追加
pub fn FallbackOrchestrator::add_provider(
  self : FallbackOrchestrator,
  provider : &@interfaces.ModelProvider,
) -> Unit {
  self.providers.push(provider)
  self.states[provider.name()] = ProviderState::new()
}

///|
/// プロバイダが利用可能かどうかをチェック
pub fn FallbackOrchestrator::is_provider_available(
  self : FallbackOrchestrator,
  provider_name : String,
  now : Int64,
) -> Bool {
  match self.states.get(provider_name) {
    Some(state) =>
      if not(state.available) {
        // クールダウン期間が経過したかチェック
        let elapsed = now - state.last_error_at
        elapsed >= self.config.cooldown_ms
      } else {
        true
      }
    None => false
  }
}

///|
/// プロバイダのエラーを記録
pub fn FallbackOrchestrator::record_error(
  self : FallbackOrchestrator,
  provider_name : String,
  now : Int64,
) -> Unit {
  match self.states.get(provider_name) {
    Some(state) => {
      let new_count = state.error_count + 1
      let available = new_count < self.config.max_retries
      self.states[provider_name] = {
        last_error_at: now,
        error_count: new_count,
        available,
      }
    }
    None => ()
  }
}

///|
/// プロバイダの成功を記録
pub fn FallbackOrchestrator::record_success(
  self : FallbackOrchestrator,
  provider_name : String,
) -> Unit {
  match self.states.get(provider_name) {
    Some(_) =>
      self.states[provider_name] = {
        last_error_at: 0L,
        error_count: 0,
        available: true,
      }
    None => ()
  }
}

///|
/// 利用可能なプロバイダを取得
pub fn FallbackOrchestrator::get_available_providers(
  self : FallbackOrchestrator,
  now : Int64,
) -> Array[&@interfaces.ModelProvider] {
  let result : Array[&@interfaces.ModelProvider] = []
  for provider in self.providers {
    if provider.is_available() &&
      self.is_provider_available(provider.name(), now) {
      result.push(provider)
    }
  }
  result
}

///|
/// ModelOrchestrator実装
pub impl @interfaces.ModelOrchestrator for FallbackOrchestrator with call(
  self,
  messages~,
  tools~,
  options~,
) {
  // 現在時刻を取得（実際にはJSのDate.now()を使用）
  let now = @js.js_date_now()
  // 利用可能なプロバイダを取得
  let available = self.get_available_providers(now)
  if available.length() == 0 {
    return @types.ModelResponse::ModelError("No providers available")
  }
  // 最初の利用可能なプロバイダで試行
  let provider = available[0]
  let response = provider.invoke(messages~, tools~, options~)
  match response {
    @types.ModelResponse::ModelError(_) => {
      self.record_error(provider.name(), now)
      // フォールバックが有効で、他のプロバイダがある場合
      if self.config.enabled && available.length() > 1 {
        let fallback = available[1]
        let fallback_response = fallback.invoke(messages~, tools~, options~)
        match fallback_response {
          @types.ModelResponse::ModelError(_) =>
            self.record_error(fallback.name(), now)
          _ => self.record_success(fallback.name())
        }
        fallback_response
      } else {
        response
      }
    }
    @types.ModelResponse::RateLimited(_) => {
      self.record_error(provider.name(), now)
      // フォールバック
      if self.config.enabled && available.length() > 1 {
        let fallback = available[1]
        fallback.invoke(messages~, tools~, options~)
      } else {
        response
      }
    }
    _ => {
      self.record_success(provider.name())
      response
    }
  }
}

///|
/// 全プロバイダの状態をリセット
pub fn FallbackOrchestrator::reset_all(self : FallbackOrchestrator) -> Unit {
  for provider in self.providers {
    self.states[provider.name()] = ProviderState::new()
  }
}

///|
/// 特定のプロバイダの状態をリセット
pub fn FallbackOrchestrator::reset_provider(
  self : FallbackOrchestrator,
  provider_name : String,
) -> Unit {
  if self.states.contains(provider_name) {
    self.states[provider_name] = ProviderState::new()
  }
}
