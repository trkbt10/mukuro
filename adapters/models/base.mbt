///|
/// モデルプロバイダエラー
pub(all) suberror ModelProviderError {
  AuthenticationFailed(String)
  RateLimited(retry_after~ : Int)
  ModelNotFound(String)
  NetworkError(String)
  Timeout
  InvalidResponse(String)
  InternalError(String)
}

///|
/// APIレスポンスの状態
pub(all) enum ApiResponseStatus {
  Success
  ClientError(Int)
  ServerError(Int)
  RateLimited(Int)
}

///|
/// HTTPステータスコードから状態を判定
pub fn status_code_to_status(code : Int) -> ApiResponseStatus {
  if code >= 200 && code < 300 {
    ApiResponseStatus::Success
  } else if code == 429 {
    ApiResponseStatus::RateLimited(60)
  } else if code >= 400 && code < 500 {
    ApiResponseStatus::ClientError(code)
  } else {
    ApiResponseStatus::ServerError(code)
  }
}
