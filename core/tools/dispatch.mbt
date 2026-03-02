///|
/// ツールディスパッチ - ツール実行のルーティング
/// すべてのツール実行はここを経由する

// =============================================================================
// Tool Dispatch
// =============================================================================

///|
/// ツールを実行（メモリストアとサブエージェントマネージャーを渡す）
pub fn execute_tool(
  name : String,
  args : Json,
  memory_store : MemoryStore?,
  agent_manager : SubAgentManager?,
  send_fn : ((@types.OutboundMessage) -> Unit)?,
) -> ToolExecutionResult {
  match name {
    "datetime" => execute_datetime(args)
    "memory" =>
      match memory_store {
        Some(store) => execute_memory(store, args)
        None => ToolExecutionResult::error("Memory store not available")
      }
    "message" =>
      match send_fn {
        Some(fn_) => execute_message(args, fn_)
        None =>
          ToolExecutionResult::error("Message sending function not available")
      }
    "spawn" =>
      match agent_manager {
        Some(manager) => execute_spawn(manager, args)
        None => ToolExecutionResult::error("Sub-agent manager not available")
      }
    "shell" => execute_shell(args)
    "filesystem" => execute_filesystem(args)
    "web" => execute_web(args)
    _ => ToolExecutionResult::error("Unknown tool: \{name}")
  }
}

///|
/// 単純なツールを実行（外部依存なし）
pub fn execute_simple_tool(name : String, args : Json) -> ToolExecutionResult {
  match name {
    "datetime" => execute_datetime(args)
    "shell" => execute_shell(args)
    "filesystem" => execute_filesystem(args)
    "web" => execute_web(args)
    _ => ToolExecutionResult::error("Unknown tool or requires dependencies: \{name}")
  }
}

///|
/// ツールが同期実行可能かチェック
pub fn is_sync_tool(name : String) -> Bool {
  match name {
    "datetime" | "memory" | "message" | "spawn" | "shell" | "filesystem" | "web" =>
      true
    _ => false
  }
}
