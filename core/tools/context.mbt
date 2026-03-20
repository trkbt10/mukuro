///|
/// ビルトインツール実行コンテキスト
pub struct BuiltinToolContext {
  memory : MemoryStore
  agent_manager : SubAgentManager
  trace : TraceStore
  send_message : (@types.OutboundMessage) -> Unit
  workspace_dir : String?
}

///|
/// ツールエントリ - 定義と実行関数を一箇所で管理
pub struct ToolEntry {
  name : String
  definition : @llm_types.ToolDefinition
  settings_schema : Json?
  execute : async (BuiltinToolContext, Json) -> ToolExecutionResult
}

///|
/// ビルトインツールコンテキストを新規作成（デフォルト値）
pub fn BuiltinToolContext::new(
  send_message : (@types.OutboundMessage) -> Unit,
) -> BuiltinToolContext {
  {
    memory: MemoryStore::new(),
    agent_manager: SubAgentManager::new(),
    trace: TraceStore::new(),
    send_message,
    workspace_dir: None,
  }
}

///|
/// ビルトインツールコンテキストを作成（全引数指定）
pub fn BuiltinToolContext::make(
  memory : MemoryStore,
  agent_manager : SubAgentManager,
  trace : TraceStore,
  send_message : (@types.OutboundMessage) -> Unit,
  workspace_dir~ : String? = None,
) -> BuiltinToolContext {
  { memory, agent_manager, trace, send_message, workspace_dir }
}

///|
/// ビルトインツールを実行（コンテキストベース）
pub async fn execute_builtin_tool(
  ctx : BuiltinToolContext,
  tool_name : String,
  args : Json,
) -> ToolExecutionResult? {
  match get_tool_entry(tool_name) {
    Some(entry) => Some((entry.execute)(ctx, args))
    None => None
  }
}
