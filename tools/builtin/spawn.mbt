///|
/// スポーンツール - サブエージェントの生成

///|
/// サブエージェント設定
pub(all) struct SubAgentConfig {
  /// エージェント名
  name : String
  /// システムプロンプト
  system_prompt : String
  /// 使用するモデル
  model : String
  /// 最大ターン数
  max_turns : Int
  /// 使用可能なツール
  tools : Array[String]
}

///|
/// デフォルトのサブエージェント設定
pub fn SubAgentConfig::default(name~ : String) -> SubAgentConfig {
  {
    name,
    system_prompt: "You are a helpful assistant.",
    model: "default",
    max_turns: 10,
    tools: [],
  }
}

///|
/// スポーンリクエスト
pub(all) struct SpawnRequest {
  /// サブエージェント設定
  config : SubAgentConfig
  /// 初期メッセージ
  initial_message : String
  /// 親エージェントへのコールバック
  callback_on_complete : Bool
}

///|
/// スポーン結果
pub(all) struct SpawnResult {
  /// サブエージェントID
  agent_id : String
  /// 状態
  status : String
  /// 最終レスポンス（完了時）
  response : String?
}

///|
/// サブエージェントマネージャ
pub struct SubAgentManager {
  /// アクティブなサブエージェント
  agents : Map[String, SpawnResult]
  /// 次のエージェントID
  mut next_id : Int
}

///|
/// SubAgentManagerを新規作成
pub fn SubAgentManager::new() -> SubAgentManager {
  { agents: {}, next_id: 1 }
}

///|
/// 新しいエージェントIDを生成
pub fn SubAgentManager::generate_id(self : SubAgentManager) -> String {
  let id = "agent_\{self.next_id}"
  self.next_id = self.next_id + 1
  id
}

///|
/// スポーンツールを実行
pub fn execute_spawn_tool(
  manager : SubAgentManager,
  args : Json,
) -> @defs.ToolExecutionResult {
  let action = match @defs.get_string_arg(args, "action") {
    Some(a) => a
    None => return @defs.ToolExecutionResult::error("Missing action argument")
  }
  match action {
    "create" => {
      let name = @defs.get_string_arg(args, "name").unwrap_or("sub_agent")
      let system_prompt = @defs.get_string_arg(args, "system_prompt").unwrap_or(
        "You are a helpful assistant.",
      )
      let message = match @defs.get_string_arg(args, "message") {
        Some(m) => m
        None =>
          return @defs.ToolExecutionResult::error("Missing message argument")
      }
      let model = @defs.get_string_arg(args, "model").unwrap_or("default")
      let max_turns = @defs.get_int_arg(args, "max_turns").unwrap_or(10)
      let agent_id = manager.generate_id()
      // サブエージェントを登録
      let result : SpawnResult = { agent_id, status: "created", response: None }
      manager.agents[agent_id] = result
      // 注: 実際のエージェント実行は別途必要
      ignore(name)
      ignore(system_prompt)
      ignore(message)
      ignore(model)
      ignore(max_turns)
      @defs.ToolExecutionResult::success({
        "agent_id": agent_id,
        "status": "created",
        "message": "Sub-agent created. Actual execution requires async implementation.",
      })
    }
    "status" => {
      let agent_id = match @defs.get_string_arg(args, "agent_id") {
        Some(id) => id
        None =>
          return @defs.ToolExecutionResult::error("Missing agent_id argument")
      }
      match manager.agents.get(agent_id) {
        Some(result) =>
          @defs.ToolExecutionResult::success({
            "agent_id": result.agent_id,
            "status": result.status,
          })
        None =>
          @defs.ToolExecutionResult::error("Agent not found: \{agent_id}")
      }
    }
    "cancel" => {
      let agent_id = match @defs.get_string_arg(args, "agent_id") {
        Some(id) => id
        None =>
          return @defs.ToolExecutionResult::error("Missing agent_id argument")
      }
      match manager.agents.get(agent_id) {
        Some(_) => {
          manager.agents[agent_id] = {
            agent_id,
            status: "cancelled",
            response: None,
          }
          @defs.ToolExecutionResult::success({
            "agent_id": agent_id,
            "status": "cancelled",
          })
        }
        None =>
          @defs.ToolExecutionResult::error("Agent not found: \{agent_id}")
      }
    }
    "result" => {
      let agent_id = match @defs.get_string_arg(args, "agent_id") {
        Some(id) => id
        None =>
          return @defs.ToolExecutionResult::error("Missing agent_id argument")
      }
      match manager.agents.get(agent_id) {
        Some(result) =>
          @defs.ToolExecutionResult::success({
            "agent_id": result.agent_id,
            "status": result.status,
            "response": match result.response {
              Some(r) => Json::string(r)
              None => Json::null()
            },
          })
        None =>
          @defs.ToolExecutionResult::error("Agent not found: \{agent_id}")
      }
    }
    _ => @defs.ToolExecutionResult::error("Unknown action: \{action}")
  }
}

// ============================================================================
// Async Sub-Agent Implementation
// ============================================================================

///|
/// 非同期サブエージェント設定
pub(all) struct AsyncSubAgentConfig {
  /// エージェント名
  name : String
  /// システムプロンプト
  system_prompt : String
  /// 最大ターン数
  max_turns : Int
  /// 使用可能なツール（"spawn"は自動的に除外される）
  allowed_tools : Array[String]
}

///|
/// デフォルト設定
pub fn AsyncSubAgentConfig::default(name~ : String) -> AsyncSubAgentConfig {
  {
    name,
    system_prompt: "You are a helpful assistant.",
    max_turns: 10,
    allowed_tools: [],
  }
}

///|
/// ツールフィルタリング（spawn再帰防止）
/// "spawn"ツールを除外して無限再帰を防止
pub fn filter_tools_for_subagent(
  registry : &@interfaces.ToolRegistry,
  allowed : Array[String],
) -> Array[@types.ToolDefinition] {
  let definitions = registry.list_definitions()
  let result : Array[@types.ToolDefinition] = []
  for def in definitions {
    // spawn ツールは除外（無限再帰防止）
    if def.name == "spawn" {
      continue
    }
    // allowed が空の場合は全てのツール（spawn以外）を許可
    if allowed.length() == 0 {
      result.push(def)
    } else if allowed.contains(def.name) {
      result.push(def)
    }
  }
  result
}

///|
/// 非同期サブエージェントを実行
/// 親エージェントからタスクを委譲されたサブエージェントを実行する
pub async fn spawn_agent_async(
  manager : SubAgentManager,
  config : AsyncSubAgentConfig,
  initial_message : String,
  model_invoke : async (
    Array[@types.ModelMessage],
    Array[@types.ToolDefinition],
    @types.ModelOptions,
  ) -> @types.ModelResponse,
  tool_registry : &@interfaces.ToolRegistry,
  model_options : @types.ModelOptions,
) -> SpawnResult {
  // エージェントIDを生成
  let agent_id = manager.generate_id()
  // 初期ステータスを登録
  manager.agents[agent_id] = { agent_id, status: "running", response: None }
  // ツール定義を取得（spawnを除外）
  let tools = filter_tools_for_subagent(tool_registry, config.allowed_tools)
  // メッセージ履歴を初期化
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System(config.system_prompt),
    @types.ModelMessage::User(content=initial_message, name=Some(config.name)),
  ]
  // サブエージェントループ
  for iteration = 0; iteration < config.max_turns; {
    // モデル呼び出し
    let response = model_invoke(messages, tools, model_options) catch {
      e => {
        let error_msg = e.to_string()
        let result : SpawnResult = {
          agent_id,
          status: "failed",
          response: Some(error_msg),
        }
        manager.agents[agent_id] = result
        return result
      }
    }
    match response {
      @types.ModelResponse::Text(content) => {
        // テキスト応答 - サブエージェント完了
        let result : SpawnResult = {
          agent_id,
          status: "completed",
          response: Some(content),
        }
        manager.agents[agent_id] = result
        return result
      }
      @types.ModelResponse::ToolCalls(calls) => {
        // ツール呼び出しを実行
        for call in calls {
          let tool_result = execute_subagent_tool_call(call, tool_registry)
          // 結果をメッセージに追加
          let result_content = match tool_result {
            @types.ToolResult::Success(content~) => content
            @types.ToolResult::Error(message~) => "Error: \{message}"
            @types.ToolResult::RequiresAction(..) =>
              "Error: RequiresAction is not supported for sub-agents"
          }
          messages.push(
            @types.ModelMessage::ToolResult(
              tool_call_id=call.id,
              content=result_content,
            ),
          )
        }
        continue iteration + 1
      }
      @types.ModelResponse::ModelError(msg) => {
        let result : SpawnResult = {
          agent_id,
          status: "failed",
          response: Some(msg),
        }
        manager.agents[agent_id] = result
        return result
      }
      @types.ModelResponse::RateLimited(retry_after~) => {
        // レート制限 - 待機してリトライ
        @async.sleep(retry_after * 1000)
        continue iteration
      }
    }
  }
  // 最大ターン数に達した
  let result : SpawnResult = {
    agent_id,
    status: "max_turns_reached",
    response: Some("Sub-agent reached maximum number of turns"),
  }
  manager.agents[agent_id] = result
  result
}

///|
/// サブエージェントのツール呼び出しを実行 (async)
async fn execute_subagent_tool_call(
  call : @types.ToolCallRequest,
  tool_registry : &@interfaces.ToolRegistry,
) -> @types.ToolResult {
  // spawnツールの呼び出しをブロック
  if call.name == "spawn" {
    return @types.ToolResult::Error(
      message="spawn tool is not available for sub-agents",
    )
  }
  match tool_registry.get_executor(call.name) {
    Some(executor) => {
      // サブエージェント用の簡易コンテキストを作成
      let session_key = @types.SessionKey::new(
        channel="internal",
        chat_id="subagent",
        user_id=None,
      )
      let dummy_session = @types.Session::new(session_key, 0L)
      let dummy_envelope : @types.InboundEnvelope = {
        channel: "internal",
        chat_id: "subagent",
        sender_id: "subagent",
        sender_name: "SubAgent",
        content: "",
        message_type: @types.MessageType::Text,
        metadata: {},
        timestamp: 0L,
      }
      let context : @types.ToolContext = {
        session: dummy_session,
        envelope: dummy_envelope,
        config: {},
      }
      executor.execute(tool_name=call.name, arguments=call.arguments, context~) catch {
        e => @types.ToolResult::Error(message=e.to_string())
      }
    }
    None => @types.ToolResult::Error(message="Tool not found: \{call.name}")
  }
}
