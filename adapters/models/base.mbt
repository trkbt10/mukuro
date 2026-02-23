///|
/// モデルプロバイダエラー
pub(all) suberror ModelProviderError {
  AuthenticationFailed(String)
  RateLimited(retry_after~ : Int)
  ModelNotFound(String)
  NetworkError(String)
  Timeout
  InvalidResponse(String)
  InternalError(String)
}

///|
/// APIレスポンスの状態
pub(all) enum ApiResponseStatus {
  Success
  ClientError(Int)
  ServerError(Int)
  RateLimited(Int)
}

///|
/// HTTPステータスコードから状態を判定
pub fn status_code_to_status(code : Int) -> ApiResponseStatus {
  if code >= 200 && code < 300 {
    ApiResponseStatus::Success
  } else if code == 429 {
    ApiResponseStatus::RateLimited(60)
  } else if code >= 400 && code < 500 {
    ApiResponseStatus::ClientError(code)
  } else {
    ApiResponseStatus::ServerError(code)
  }
}

///|
/// ModelMessageをJSON形式に変換（Anthropic形式）
pub fn message_to_anthropic_json(message : @types.ModelMessage) -> Json {
  match message {
    @types.ModelMessage::System(content) =>
      { "role": "system", "content": content }
    @types.ModelMessage::User(content~, name~) =>
      match name {
        Some(n) => { "role": "user", "content": content, "name": n }
        None => { "role": "user", "content": content }
      }
    @types.ModelMessage::Assistant(content~, tool_calls~) =>
      match tool_calls {
        Some(calls) => {
          let tool_use : Array[Json] = []
          for call in calls {
            tool_use.push({
              "type": "tool_use",
              "id": call.id,
              "name": call.name,
              "input": call.arguments,
            })
          }
          { "role": "assistant", "content": Json::array(tool_use) }
        }
        None => { "role": "assistant", "content": content }
      }
    @types.ModelMessage::ToolResult(tool_call_id~, content~) =>
      {
        "role": "user",
        "content": Json::array([
          {
            "type": "tool_result",
            "tool_use_id": tool_call_id,
            "content": content,
          },
        ]),
      }
  }
}

///|
/// ModelMessageをJSON形式に変換（OpenAI形式）
pub fn message_to_openai_json(message : @types.ModelMessage) -> Json {
  match message {
    @types.ModelMessage::System(content) =>
      { "role": "system", "content": content }
    @types.ModelMessage::User(content~, name~) =>
      match name {
        Some(n) => { "role": "user", "content": content, "name": n }
        None => { "role": "user", "content": content }
      }
    @types.ModelMessage::Assistant(content~, tool_calls~) =>
      match tool_calls {
        Some(calls) => {
          let tool_calls_json : Array[Json] = []
          for call in calls {
            tool_calls_json.push({
              "id": call.id,
              "type": "function",
              "function": {
                "name": call.name,
                "arguments": call.arguments.stringify(),
              },
            })
          }
          {
            "role": "assistant",
            "content": content,
            "tool_calls": Json::array(tool_calls_json),
          }
        }
        None => { "role": "assistant", "content": content }
      }
    @types.ModelMessage::ToolResult(tool_call_id~, content~) =>
      { "role": "tool", "tool_call_id": tool_call_id, "content": content }
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
/// ToolDefinitionをJSON形式に変換（OpenAI形式）
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
/// Anthropicレスポンスからツール呼び出しをパース
pub fn parse_anthropic_tool_calls(
  content : Json,
) -> Array[@types.ToolCallRequest] {
  let result : Array[@types.ToolCallRequest] = []
  match content {
    Array(items) =>
      for item in items {
        match item {
          {
            "type": String("tool_use"),
            "id": String(id),
            "name": String(name),
            "input": input,
            ..
          } =>
            result.push(
              @types.ToolCallRequest::new(id~, name~, arguments=input),
            )
          _ => ()
        }
      }
    _ => ()
  }
  result
}

///|
/// OpenAIレスポンスからツール呼び出しをパース
pub fn parse_openai_tool_calls(
  tool_calls : Json,
) -> Array[@types.ToolCallRequest] {
  let result : Array[@types.ToolCallRequest] = []
  match tool_calls {
    Array(calls) =>
      for call in calls {
        match call {
          {
            "id": String(id),
            "function": {
              "name": String(name),
              "arguments": String(args_str),
              ..
            },
            ..
          } => {
            let arguments : Json = @json.parse(args_str) catch { _ => {} }
            result.push(@types.ToolCallRequest::new(id~, name~, arguments~))
          }
          _ => ()
        }
      }
    _ => ()
  }
  result
}
