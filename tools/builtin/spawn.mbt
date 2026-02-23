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
/// スポーンツール定義
pub fn spawn_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="spawn",
    description="Create a sub-agent to handle a specific task",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([
            Json::string("create"),
            Json::string("status"),
            Json::string("cancel"),
            Json::string("result"),
          ]),
          "description": "Action to perform",
        },
        "name": string_param("Sub-agent name (for create)", false),
        "system_prompt": string_param("System prompt for sub-agent", false),
        "message": string_param("Initial message/task for sub-agent", false),
        "model": string_param(
          "Model to use (default: inherit from parent)", false,
        ),
        "max_turns": integer_param("Maximum conversation turns"),
        "tools": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Tools available to sub-agent",
        },
        "agent_id": string_param("Agent ID (for status/cancel/result)", false),
      },
      ["action"],
    ),
  )
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
) -> ToolExecutionResult {
  let action = match get_string_arg(args, "action") {
    Some(a) => a
    None => return ToolExecutionResult::error("Missing action argument")
  }
  match action {
    "create" => {
      let name = get_string_arg(args, "name").unwrap_or("sub_agent")
      let system_prompt = get_string_arg(args, "system_prompt").unwrap_or(
        "You are a helpful assistant.",
      )
      let message = match get_string_arg(args, "message") {
        Some(m) => m
        None => return ToolExecutionResult::error("Missing message argument")
      }
      let model = get_string_arg(args, "model").unwrap_or("default")
      let max_turns = get_int_arg(args, "max_turns").unwrap_or(10)
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
      ToolExecutionResult::success({
        "agent_id": agent_id,
        "status": "created",
        "message": "Sub-agent created. Actual execution requires async implementation.",
      })
    }
    "status" => {
      let agent_id = match get_string_arg(args, "agent_id") {
        Some(id) => id
        None => return ToolExecutionResult::error("Missing agent_id argument")
      }
      match manager.agents.get(agent_id) {
        Some(result) =>
          ToolExecutionResult::success({
            "agent_id": result.agent_id,
            "status": result.status,
          })
        None => ToolExecutionResult::error("Agent not found: \{agent_id}")
      }
    }
    "cancel" => {
      let agent_id = match get_string_arg(args, "agent_id") {
        Some(id) => id
        None => return ToolExecutionResult::error("Missing agent_id argument")
      }
      match manager.agents.get(agent_id) {
        Some(_) => {
          manager.agents[agent_id] = {
            agent_id,
            status: "cancelled",
            response: None,
          }
          ToolExecutionResult::success({
            "agent_id": agent_id,
            "status": "cancelled",
          })
        }
        None => ToolExecutionResult::error("Agent not found: \{agent_id}")
      }
    }
    "result" => {
      let agent_id = match get_string_arg(args, "agent_id") {
        Some(id) => id
        None => return ToolExecutionResult::error("Missing agent_id argument")
      }
      match manager.agents.get(agent_id) {
        Some(result) =>
          ToolExecutionResult::success({
            "agent_id": result.agent_id,
            "status": result.status,
            "response": match result.response {
              Some(r) => Json::string(r)
              None => Json::null()
            },
          })
        None => ToolExecutionResult::error("Agent not found: \{agent_id}")
      }
    }
    _ => ToolExecutionResult::error("Unknown action: \{action}")
  }
}
