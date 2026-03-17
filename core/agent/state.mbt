///|
/// エージェントの状態
pub(all) enum AgentState {
  /// 待機中
  Idle
  /// 入力を処理中
  Processing(@types.InboundEnvelope)
  /// モデル応答を待機中
  WaitingForModel
  /// ツールを実行中
  ExecutingTool(tool_name~ : String, call_id~ : String)
  /// 応答を送信中
  SendingResponse
  /// エラー発生
  Error(String)
  /// 完了
  Completed
}

///|
/// AgentStateのShow実装
pub impl Show for AgentState with output(self, logger) {
  match self {
    AgentState::Idle => logger.write_string("Idle")
    AgentState::Processing(_) => logger.write_string("Processing(...)")
    AgentState::WaitingForModel => logger.write_string("WaitingForModel")
    AgentState::ExecutingTool(tool_name~, call_id~) =>
      logger.write_string("ExecutingTool(\{tool_name}, \{call_id})")
    AgentState::Error(msg) => logger.write_string("Error(\{msg})")
    AgentState::SendingResponse => logger.write_string("SendingResponse")
    AgentState::Completed => logger.write_string("Completed")
  }
}

///|
/// エージェントループの反復結果
pub(all) enum IterationResult {
  /// 処理継続（ツール呼び出し後など）
  Continue(Array[@llm_types.ModelMessage])
  /// 完了（応答を返す）
  Complete(@types.OutboundMessage)
  /// エラー終了
  Failed(String)
}

///|
/// エージェントループのコンテキスト
pub(all) struct AgentLoopContext {
  /// 現在の状態
  mut state : AgentState
  /// 反復回数
  mut iteration : Int
  /// 現在のメッセージ列
  mut messages : Array[@llm_types.ModelMessage]
  /// ツール呼び出し履歴
  tool_call_history : Array[@llm_types.ToolCallRequest]
}

///|
/// AgentLoopContextを新規作成
pub fn AgentLoopContext::new() -> AgentLoopContext {
  { state: AgentState::Idle, iteration: 0, messages: [], tool_call_history: [] }
}

///|
/// 状態を更新
pub fn AgentLoopContext::set_state(
  self : AgentLoopContext,
  state : AgentState,
) -> Unit {
  self.state = state
}

///|
/// 反復回数をインクリメント
pub fn AgentLoopContext::increment_iteration(self : AgentLoopContext) -> Unit {
  self.iteration = self.iteration + 1
}

///|
/// メッセージを追加
pub fn AgentLoopContext::add_message(
  self : AgentLoopContext,
  message : @llm_types.ModelMessage,
) -> Unit {
  self.messages.push(message)
}

///|
/// ツール呼び出しを記録
pub fn AgentLoopContext::record_tool_call(
  self : AgentLoopContext,
  call : @llm_types.ToolCallRequest,
) -> Unit {
  self.tool_call_history.push(call)
}

///|
/// 最大反復回数に達したかどうか
pub fn AgentLoopContext::is_max_iterations(
  self : AgentLoopContext,
  max : Int,
) -> Bool {
  self.iteration >= max
}

///|
/// エラー状態かどうか
pub fn AgentLoopContext::is_error(self : AgentLoopContext) -> Bool {
  match self.state {
    AgentState::Error(_) => true
    _ => false
  }
}

///|
/// 完了状態かどうか
pub fn AgentLoopContext::is_completed(self : AgentLoopContext) -> Bool {
  match self.state {
    AgentState::Completed => true
    _ => false
  }
}
