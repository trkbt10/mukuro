///|
/// モデルオーケストレータ トレイト
/// LLMモデルの呼び出しを抽象化する (async)
pub(open) trait ModelOrchestrator {
  /// モデルを呼び出し応答を取得 (async)
  async call(
    Self,
    messages~ : Array[@llm_types.ModelMessage],
    tools~ : Array[@llm_types.ToolDefinition],
    options~ : @types.ModelOptions,
  ) -> @llm_types.ModelResponse
  /// ストリーミング付きでモデルを呼び出し (async)
  /// on_stream_event は SSE イベントごとに呼ばれる
  /// デフォルト実装は on_stream_event を無視して call に委譲
  async call_streaming(
    Self,
    messages~ : Array[@llm_types.ModelMessage],
    tools~ : Array[@llm_types.ToolDefinition],
    options~ : @types.ModelOptions,
    on_stream_event~ : ((String, Json)) -> Unit,
  ) -> @llm_types.ModelResponse = _
}

///|
/// call_streaming のデフォルト実装: on_stream_event を無視して call に委譲
impl ModelOrchestrator with call_streaming(
  self,
  messages~,
  tools~,
  options~,
  on_stream_event~,
) {
  ignore(on_stream_event)
  self.call(messages~, tools~, options~)
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
    messages~ : Array[@llm_types.ModelMessage],
    tools~ : Array[@llm_types.ToolDefinition],
    options~ : @types.ModelOptions,
  ) -> @llm_types.ModelResponse
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
