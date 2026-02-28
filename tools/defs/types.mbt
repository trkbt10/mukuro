///|
/// ツール実行エラー
pub(all) suberror ToolExecutionError {
  InvalidArguments(String)
  ExecutionFailed(String)
  PermissionDenied(String)
  NotFound(String)
  Timeout
}

///|
/// ツール結果の状態
pub(all) enum ToolResultStatus {
  Success
  Error
  RequiresConfirmation
}

///|
/// ツール実行結果
pub(all) struct ToolExecutionResult {
  /// 状態
  status : ToolResultStatus
  /// 結果データ（JSON）
  data : Json
  /// エラーメッセージ（エラー時）
  error_message : String?
}

///|
/// 成功結果を作成
pub fn ToolExecutionResult::success(data : Json) -> ToolExecutionResult {
  { status: ToolResultStatus::Success, data, error_message: None }
}

///|
/// エラー結果を作成
pub fn ToolExecutionResult::error(message : String) -> ToolExecutionResult {
  { status: ToolResultStatus::Error, data: {}, error_message: Some(message) }
}

///|
/// 確認要求結果を作成
pub fn ToolExecutionResult::requires_confirmation(
  data : Json,
) -> ToolExecutionResult {
  { status: ToolResultStatus::RequiresConfirmation, data, error_message: None }
}
