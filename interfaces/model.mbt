///|
/// モデルオーケストレータ トレイト
/// LLMモデルの呼び出しを抽象化する (async)
pub(open) trait ModelOrchestrator {
  /// モデルを呼び出し応答を取得 (async)
  async call(
    Self,
    messages~ : Array[@types.ModelMessage],
    tools~ : Array[@types.ToolDefinition],
    options~ : @types.ModelOptions,
  ) -> @types.ModelResponse
}

///|
/// モデルプロバイダ トレイト
/// 特定のLLMプロバイダへの接続を担当する (async)
pub(open) trait ModelProvider {
  /// プロバイダ名を取得
  name(Self) -> String
  /// 利用可能かどうか
  is_available(Self) -> Bool
  /// モデルを呼び出し (async)
  async invoke(
    Self,
    messages~ : Array[@types.ModelMessage],
    tools~ : Array[@types.ToolDefinition],
    options~ : @types.ModelOptions,
  ) -> @types.ModelResponse
}

///|
/// プロバイダ解決トレイト
/// config 等から ProviderConfig を取得する抽象化層
pub(open) trait ProviderResolver {
  resolve(Self) -> @types.ProviderConfig?
}

///|
/// プロバイダエラー種別
pub(all) enum ProviderError {
  /// 認証エラー
  AuthenticationFailed(String)
  /// レート制限
  RateLimited(retry_after~ : Int)
  /// モデル不明
  ModelNotFound(String)
  /// ネットワークエラー
  NetworkError(String)
  /// タイムアウト
  Timeout
  /// 内部エラー
  InternalError(String)
}

///|
/// プロバイダエラーがリトライ可能かどうか
pub fn ProviderError::is_retriable(self : ProviderError) -> Bool {
  match self {
    ProviderError::RateLimited(_) => true
    ProviderError::NetworkError(_) => true
    ProviderError::Timeout => true
    _ => false
  }
}
