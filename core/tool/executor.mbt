///|
/// ツール実行エラー
pub(all) suberror ToolExecutionError {
  ToolNotFound(String)
  InvalidArguments(String)
  ExecutionFailed(String)
  PermissionDenied(String)
  Timeout
}

///|
/// ツール実行マネージャ
/// レジストリと連携してツールを実行する
pub struct ToolExecutionManager {
  registry : &@interfaces.ToolRegistry
}

///|
/// ToolExecutionManagerを新規作成
pub fn ToolExecutionManager::new(
  registry : &@interfaces.ToolRegistry,
) -> ToolExecutionManager {
  { registry, }
}

///|
/// ツールを実行
pub fn ToolExecutionManager::execute(
  self : ToolExecutionManager,
  tool_name : String,
  arguments : Json,
  context : @types.ToolContext,
) -> @types.ToolResult raise ToolExecutionError {
  // 1. ツール実行者を取得
  let executor = match self.registry.get_executor(tool_name) {
    Some(e) => e
    None => raise ToolExecutionError::ToolNotFound(tool_name)
  }
  // 2. ツールを実行
  executor.execute(tool_name~, arguments~, context~) catch {
    e => raise ToolExecutionError::ExecutionFailed(e.to_string())
  }
}

///|
/// 複数のツール呼び出しを実行
pub fn ToolExecutionManager::execute_calls(
  self : ToolExecutionManager,
  calls : Array[@types.ToolCallRequest],
  context : @types.ToolContext,
) -> Array[(@types.ToolCallRequest, @types.ToolResult)] raise ToolExecutionError {
  let results : Array[(@types.ToolCallRequest, @types.ToolResult)] = []
  for call in calls {
    let result = self.execute(call.name, call.arguments, context)
    results.push((call, result))
  }
  results
}

///|
/// ツール実行結果をModelMessageに変換
pub fn tool_result_to_message(
  call_id : String,
  result : @types.ToolResult,
) -> @types.ModelMessage {
  let content = match result {
    @types.ToolResult::Success(content~) => content
    @types.ToolResult::Error(message~) => "Error: \{message}"
    @types.ToolResult::RequiresAction(next_tool~, arguments~) =>
      "RequiresAction: \{next_tool} with \{arguments}"
  }
  @types.ModelMessage::ToolResult(tool_call_id=call_id, content~)
}

///|
/// ToolResultが成功かどうか
pub fn is_success(result : @types.ToolResult) -> Bool {
  match result {
    @types.ToolResult::Success(_) => true
    _ => false
  }
}

///|
/// ToolResultがエラーかどうか
pub fn is_error(result : @types.ToolResult) -> Bool {
  match result {
    @types.ToolResult::Error(_) => true
    _ => false
  }
}

///|
/// ToolResultが追加アクションを必要とするかどうか
pub fn requires_action(result : @types.ToolResult) -> Bool {
  match result {
    @types.ToolResult::RequiresAction(..) => true
    _ => false
  }
}
