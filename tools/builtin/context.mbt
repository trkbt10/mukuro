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
