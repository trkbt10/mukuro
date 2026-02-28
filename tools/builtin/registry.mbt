///|
/// ビルトインツールレジストリ - 共通コード

///|
/// ツール名で定義を取得
pub fn get_tool_definition(name : String) -> @types.ToolDefinition? {
  for tool in get_all_tool_definitions() {
    if tool.name == name {
      return Some(tool)
    }
  }
  None
}

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
  {
    memory: MemoryStore::new(),
    agent_manager: SubAgentManager::new(),
    send_message,
  }
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
/// 同期ツールを実行
pub fn execute_sync_tool(
  ctx : BuiltinToolContext,
  tool_name : String,
  args : Json,
) -> ToolExecutionResult? {
  match tool_name {
    "datetime" => Some(execute_datetime_tool(args))
    "memory" => Some(execute_memory_tool(ctx.memory, args))
    "spawn" => Some(execute_spawn_tool(ctx.agent_manager, args))
    "message" => Some(execute_message_tool(args, ctx.send_message))
    _ => None
  }
}

///|
/// ツールが同期かどうか
pub fn is_sync_tool(tool_name : String) -> Bool {
  match tool_name {
    "datetime" | "memory" | "spawn" | "message" => true
    _ => false
  }
}
