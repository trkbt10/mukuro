///|
/// ToolDefinitionをJSON形式に変換（OpenAI Chat Completions形式）
pub fn tool_to_openai_json(tool : @types.ToolDefinition) -> Json {
  {
    "type": "function",
    "function": {
      "name": tool.name,
      "description": tool.description,
      "parameters": tool.parameters,
    },
  }
}

///|
/// ToolDefinitionをJSON形式に変換（Responses API形式）
pub fn tool_to_responses_api_json(tool : @types.ToolDefinition) -> Json {
  {
    "type": "function",
    "name": tool.name,
    "description": tool.description,
    "parameters": tool.parameters,
  }
}

///|
/// ToolDefinitionをJSON形式に変換（Anthropic形式）
pub fn tool_to_anthropic_json(tool : @types.ToolDefinition) -> Json {
  {
    "name": tool.name,
    "description": tool.description,
    "input_schema": tool.parameters,
  }
}

///|
/// ツール定義配列をOpenAI Chat Completions形式のJSON配列に変換
pub fn tools_to_openai_json(
  tools : Array[@types.ToolDefinition],
) -> Array[Json] {
  let result : Array[Json] = []
  for tool in tools {
    result.push(tool_to_openai_json(tool))
  }
  result
}

///|
/// ツール定義配列をResponses API形式のJSON配列に変換
pub fn tools_to_responses_api_json(
  tools : Array[@types.ToolDefinition],
) -> Array[Json] {
  let result : Array[Json] = []
  for tool in tools {
    result.push(tool_to_responses_api_json(tool))
  }
  result
}

///|
/// ツール定義配列をAnthropic形式のJSON配列に変換
pub fn tools_to_anthropic_json(
  tools : Array[@types.ToolDefinition],
) -> Array[Json] {
  let result : Array[Json] = []
  for tool in tools {
    result.push(tool_to_anthropic_json(tool))
  }
  result
}
