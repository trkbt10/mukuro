///|
/// ビルトインツール実行コンテキスト

///|
/// ビルトインツール実行コンテキスト
pub struct BuiltinToolContext {
  /// メモリストア
  memory : MemoryStore
  /// サブエージェントマネージャ
  agent_manager : SubAgentManager
  /// メッセージ送信関数
  send_message : (@types.OutboundMessage) -> Unit
}

///|
/// ビルトインツールコンテキストを新規作成
pub fn BuiltinToolContext::new(
  send_message : (@types.OutboundMessage) -> Unit,
) -> BuiltinToolContext {
  { memory: MemoryStore::new(), agent_manager: SubAgentManager::new(), send_message }
}

///|
/// 外部から MemoryStore を注入してコンテキストを作成
pub fn BuiltinToolContext::with_memory(
  memory : MemoryStore,
  send_message : (@types.OutboundMessage) -> Unit,
) -> BuiltinToolContext {
  { memory, agent_manager: SubAgentManager::new(), send_message }
}

///|
/// ビルトインツールを実行（コンテキストベース）
pub fn execute_builtin_tool(
  ctx : BuiltinToolContext,
  tool_name : String,
  args : Json,
) -> ToolExecutionResult? {
  match tool_name {
    "datetime" => Some(execute_datetime(args))
    "memory" => Some(execute_memory(ctx.memory, args))
    "spawn" => Some(execute_spawn(ctx.agent_manager, args))
    "message" => Some(execute_message(args, ctx.send_message))
    "shell" => Some(execute_shell(args))
    "filesystem" => Some(execute_filesystem(args))
    "web" => Some(execute_web(args))
    _ => None
  }
}
