///|
/// Spawnツール - サブエージェントの生成
/// 定義と実装を統合

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn spawn_tool() -> @llm_types.ToolDefinition {
  make_tool_definition(
    name="spawn",
    description="Create autonomous sub-agents for parallel or complex tasks. Use for: delegating research, running background tasks, breaking down complex work. Sub-agents have their own conversation loop and can use tools. Parent agent can check status and retrieve results.",
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
          "description": "Action: 'create' new sub-agent, 'status' check progress, 'cancel' stop agent, 'result' get final output",
        },
        "name": string_param(
          "Descriptive name for the sub-agent (e.g., 'researcher', 'code-reviewer')",
        ),
        "system_prompt": string_param(
          "Instructions/persona for the sub-agent. Define its role and constraints.",
        ),
        "message": string_param(
          "Initial task or question for the sub-agent to work on",
        ),
        "model": string_param(
          "LLM model name (default: inherit from parent agent)",
        ),
        "max_turns": integer_param(
          "Maximum conversation turns before auto-stop (default: 10)",
        ),
        "tools": {
          "type": "array",
          "items": { "type": "string" },
          "description": "List of tool names sub-agent can use (empty = all except spawn)",
        },
        "agent_id": string_param(
          "Sub-agent ID returned from 'create' (required for status/cancel/result)",
        ),
      },
      ["action"],
    ),
  )
}

// =============================================================================
// Sub-Agent Types
// =============================================================================

///|
pub(all) struct SubAgentConfig {
  name : String
  system_prompt : String
  model : String
  max_turns : Int
  tools : Array[String]
}

///|
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
pub(all) struct SpawnRequest {
  config : SubAgentConfig
  initial_message : String
  callback_on_complete : Bool
}

///|
pub(all) struct SpawnResult {
  agent_id : String
  status : String
  response : String?
}

///|
pub struct SubAgentManager {
  agents : Map[String, SpawnResult]
  mut next_id : Int
}

///|
pub fn SubAgentManager::new() -> SubAgentManager {
  { agents: {}, next_id: 1 }
}

///|
pub fn SubAgentManager::generate_id(self : SubAgentManager) -> String {
  let id = "agent_\{self.next_id}"
  self.next_id = self.next_id + 1
  id
}

// =============================================================================
// Tool Implementation
// =============================================================================

///|
/// Spawnツールエントリ
pub fn spawn_entry() -> ToolEntry {
  {
    name: "spawn",
    definition: spawn_tool(),
    settings_schema: None,
    execute: fn(ctx, args) { execute_spawn(ctx.agent_manager, args) },
  }
}

///|
fn execute_spawn(manager : SubAgentManager, args : Json) -> ToolExecutionResult {
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
      let result : SpawnResult = { agent_id, status: "created", response: None }
      manager.agents[agent_id] = result
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

// =============================================================================
// Async Sub-Agent
// =============================================================================

///|
pub(all) struct AsyncSubAgentConfig {
  name : String
  system_prompt : String
  max_turns : Int
  allowed_tools : Array[String]
}

///|
pub fn AsyncSubAgentConfig::default(name~ : String) -> AsyncSubAgentConfig {
  {
    name,
    system_prompt: "You are a helpful assistant.",
    max_turns: 10,
    allowed_tools: [],
  }
}

///|
pub fn filter_tools_for_subagent(
  registry : &@interfaces.ToolRegistry,
  allowed : Array[String],
) -> Array[@llm_types.ToolDefinition] {
  let definitions = registry.list_definitions()
  let result : Array[@llm_types.ToolDefinition] = []
  for def in definitions {
    if def.name == "spawn" {
      continue
    }
    if allowed.length() == 0 {
      result.push(def)
    } else if allowed.contains(def.name) {
      result.push(def)
    }
  }
  result
}

///|
pub async fn spawn_agent_async(
  manager : SubAgentManager,
  config : AsyncSubAgentConfig,
  initial_message : String,
  model_invoke : async (
    Array[@llm_types.ModelMessage],
    Array[@llm_types.ToolDefinition],
    @types.ModelOptions,
  ) -> @llm_types.ModelResponse,
  tool_registry : &@interfaces.ToolRegistry,
  model_options : @types.ModelOptions,
) -> SpawnResult {
  let agent_id = manager.generate_id()
  manager.agents[agent_id] = { agent_id, status: "running", response: None }
  let tools = filter_tools_for_subagent(tool_registry, config.allowed_tools)
  let messages : Array[@llm_types.ModelMessage] = [
    @llm_types.ModelMessage::System(config.system_prompt),
    @llm_types.ModelMessage::User(
      content=initial_message,
      name=Some(config.name),
    ),
  ]
  for iteration = 0; iteration < config.max_turns; {
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
      @llm_types.ModelResponse::Text(content)
      | @llm_types.ModelResponse::RichText({ content, .. }) => {
        let result : SpawnResult = {
          agent_id,
          status: "completed",
          response: Some(content),
        }
        manager.agents[agent_id] = result
        return result
      }
      @llm_types.ModelResponse::ToolCalls(calls) => {
        for call in calls {
          let tool_result = execute_subagent_tool_call(call, tool_registry)
          let result_content = match tool_result {
            @types.ToolResult::Success(content~) => content
            @types.ToolResult::Error(message~) => "Error: \{message}"
            @types.ToolResult::RequiresAction(..) =>
              "Error: RequiresAction is not supported for sub-agents"
          }
          messages.push(
            @llm_types.ModelMessage::ToolResult(
              tool_call_id=call.id,
              content=result_content,
            ),
          )
        }
        continue iteration + 1
      }
      @llm_types.ModelResponse::ModelError(msg) => {
        let result : SpawnResult = {
          agent_id,
          status: "failed",
          response: Some(msg),
        }
        manager.agents[agent_id] = result
        return result
      }
      @llm_types.ModelResponse::RateLimited(retry_after~) => {
        @async.sleep(retry_after * 1000)
        continue iteration
      }
    }
  }
  let result : SpawnResult = {
    agent_id,
    status: "max_turns_reached",
    response: Some("Sub-agent reached maximum number of turns"),
  }
  manager.agents[agent_id] = result
  result
}

///|
async fn execute_subagent_tool_call(
  call : @llm_types.ToolCallRequest,
  tool_registry : &@interfaces.ToolRegistry,
) -> @types.ToolResult {
  if call.name == "spawn" {
    return @types.ToolResult::Error(
      message="spawn tool is not available for sub-agents",
    )
  }
  match tool_registry.get_executor(call.name) {
    Some(executor) => {
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
