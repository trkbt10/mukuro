///|
/// ツールディスパッチ - ツール実行のルーティング
/// すべてのツール実行はレジストリを経由する

// =============================================================================
// Tool Dispatch
// =============================================================================

///|
/// ツールを実行（レガシー互換: 個別依存を渡す）
pub async fn execute_tool(
  name : String,
  args : Json,
  memory_store : MemoryStore?,
  agent_manager : SubAgentManager?,
  send_fn : ((@types.OutboundMessage) -> Unit)?,
) -> ToolExecutionResult {
  let ctx = {
    memory: memory_store.unwrap_or(MemoryStore::new()),
    agent_manager: agent_manager.unwrap_or(SubAgentManager::new()),
    trace: TraceStore::new(),
    send_message: send_fn.unwrap_or(fn(_) {  }),
    workspace_dir: None,
  }
  match execute_builtin_tool(ctx, name, args) {
    Some(result) => result
    None => ToolExecutionResult::error("Unknown tool: \{name}")
  }
}

///|
/// 単純なツールを実行（外部依存なし）
pub async fn execute_simple_tool(
  name : String,
  args : Json,
) -> ToolExecutionResult {
  execute_tool(name, args, None, None, None)
}

///|
/// ツールが同期実行可能かチェック
pub fn is_sync_tool(name : String) -> Bool {
  has_tool(name)
}
