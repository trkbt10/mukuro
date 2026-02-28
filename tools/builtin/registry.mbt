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

