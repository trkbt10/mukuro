///|
/// ModelMessageをJSON形式に変換（OpenAI Chat Completions形式）
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
/// メッセージ配列をOpenAI Chat Completions形式のJSON配列に変換
pub fn messages_to_openai_json(
  messages : Array[@types.ModelMessage],
) -> Array[Json] {
  let result : Array[Json] = []
  for msg in messages {
    result.push(message_to_openai_json(msg))
  }
  result
}

///|
/// メッセージ配列をAnthropic形式のJSON配列に変換（Systemメッセージ除外）
pub fn messages_to_anthropic_json(
  messages : Array[@types.ModelMessage],
) -> Array[Json] {
  let result : Array[Json] = []
  for msg in messages {
    match msg {
      @types.ModelMessage::System(_) => ()
      @types.ModelMessage::User(content~, ..) =>
        result.push({ "role": "user", "content": content })
      @types.ModelMessage::Assistant(content~, tool_calls~) =>
        match tool_calls {
          Some(calls) if calls.length() > 0 => {
            let content_blocks : Array[Json] = []
            if content.length() > 0 {
              content_blocks.push({ "type": "text", "text": content })
            }
            for call in calls {
              content_blocks.push({
                "type": "tool_use",
                "id": call.id,
                "name": call.name,
                "input": call.arguments,
              })
            }
            result.push({
              "role": "assistant",
              "content": Json::array(content_blocks),
            })
          }
          _ => result.push({ "role": "assistant", "content": content })
        }
      @types.ModelMessage::ToolResult(tool_call_id~, content~) =>
        result.push({
          "role": "user",
          "content": Json::array([
            {
              "type": "tool_result",
              "tool_use_id": tool_call_id,
              "content": content,
            },
          ]),
        })
    }
  }
  result
}

///|
/// メッセージ配列をResponses API input items形式のJSON配列に変換
pub fn messages_to_responses_input(
  messages : Array[@types.ModelMessage],
) -> Array[Json] {
  let input_items : Array[Json] = []
  for msg in messages {
    match msg {
      @types.ModelMessage::System(content) =>
        input_items.push({ "role": "system", "content": content })
      @types.ModelMessage::User(content~, ..) =>
        input_items.push({ "role": "user", "content": content })
      @types.ModelMessage::Assistant(content~, tool_calls~) =>
        match tool_calls {
          Some(calls) if calls.length() > 0 => {
            if content.length() > 0 {
              input_items.push({ "role": "assistant", "content": content })
            }
            for call in calls {
              input_items.push({
                "type": "function_call",
                "call_id": call.id,
                "name": call.name,
                "arguments": call.arguments.stringify(),
                "status": "completed",
              })
            }
          }
          _ =>
            input_items.push({ "role": "assistant", "content": content })
        }
      @types.ModelMessage::ToolResult(tool_call_id~, content~) =>
        input_items.push({
          "type": "function_call_output",
          "call_id": tool_call_id,
          "output": content,
        })
    }
  }
  input_items
}

///|
/// メッセージ配列からシステムメッセージを抽出
pub fn extract_system_message(
  messages : Array[@types.ModelMessage],
) -> String {
  for msg in messages {
    match msg {
      @types.ModelMessage::System(content) => return content
      _ => ()
    }
  }
  ""
}
