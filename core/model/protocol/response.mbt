///|
/// OpenAI Chat Completionsレスポンスをパース
pub fn parse_openai_chat_response(json : Json) -> @types.ModelResponse {
  match json {
    { "choices": Array(choices), .. } => {
      if choices.length() == 0 {
        return @types.ModelResponse::ModelError("No choices in response")
      }
      let choice = choices[0]
      match choice {
        { "message": message, "finish_reason": String(finish_reason), .. } => {
          // ツール呼び出しをチェック
          if finish_reason == "tool_calls" {
            match message {
              { "tool_calls": tool_calls, .. } => {
                let calls = parse_openai_tool_calls(tool_calls)
                if calls.length() > 0 {
                  return @types.ModelResponse::ToolCalls(calls)
                }
              }
              _ => ()
            }
          }
          // テキスト応答を抽出
          match message {
            { "content": String(content), .. } =>
              @types.ModelResponse::Text(content)
            { "content": Null, "tool_calls": tool_calls, .. } => {
              let calls = parse_openai_tool_calls(tool_calls)
              if calls.length() > 0 {
                @types.ModelResponse::ToolCalls(calls)
              } else {
                @types.ModelResponse::Text("")
              }
            }
            _ => @types.ModelResponse::ModelError("Invalid message format")
          }
        }
        _ => @types.ModelResponse::ModelError("Invalid choice format")
      }
    }
    { "error": { "message": String(msg), .. }, .. } =>
      @types.ModelResponse::ModelError(msg)
    _ => @types.ModelResponse::ModelError("Unknown response format")
  }
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

///|
/// OpenAI Responses APIレスポンスをパース
pub fn parse_responses_api_response(
  response_json : Json,
) -> @types.ModelResponse {
  match response_json {
    { "output": Array(outputs), .. } => {
      let text = StringBuilder::new()
      let tool_calls : Array[@types.ToolCallRequest] = []
      for output in outputs {
        match output {
          { "type": String("message"), "content": Array(contents), .. } =>
            for content in contents {
              match content {
                { "type": String("output_text"), "text": String(t), .. } => {
                  if text.to_string().length() > 0 {
                    text.write_char('\n')
                  }
                  text.write_string(t)
                }
                _ => ()
              }
            }
          {
            "type": String("function_call"),
            "name": String(name),
            "arguments": String(args_str),
            ..
          } => {
            let id = match output {
              { "call_id": String(cid), .. } => cid
              { "id": String(fid), .. } => fid
              _ => ""
            }
            let arguments : Json = @json.parse(args_str) catch { _ => {} }
            tool_calls.push(
              @types.ToolCallRequest::new(id~, name~, arguments~),
            )
          }
          _ => () // reasoning, web_search_call, etc.
        }
      }
      if tool_calls.length() > 0 {
        @types.ModelResponse::ToolCalls(tool_calls)
      } else {
        @types.ModelResponse::Text(text.to_string())
      }
    }
    { "error": { "message": String(msg), .. }, .. } =>
      @types.ModelResponse::ModelError(msg)
    _ => @types.ModelResponse::ModelError("Unknown response format")
  }
}

///|
/// Anthropicレスポンスをパース
pub fn parse_anthropic_response(response_json : Json) -> @types.ModelResponse {
  match response_json {
    { "content": content, "stop_reason": String(stop_reason), .. } => {
      // ツール使用をチェック
      if stop_reason == "tool_use" {
        let tool_calls = parse_anthropic_tool_calls(content)
        if tool_calls.length() > 0 {
          return @types.ModelResponse::ToolCalls(tool_calls)
        }
      }
      // テキスト応答を抽出
      match content {
        Array(blocks) => {
          let text = StringBuilder::new()
          for block in blocks {
            match block {
              { "type": String("text"), "text": String(t), .. } => {
                if text.to_string().length() > 0 {
                  text.write_char('\n')
                }
                text.write_string(t)
              }
              _ => ()
            }
          }
          @types.ModelResponse::Text(text.to_string())
        }
        _ => @types.ModelResponse::ModelError("Invalid content format")
      }
    }
    { "error": { "message": String(msg), .. }, .. } =>
      @types.ModelResponse::ModelError(msg)
    _ => @types.ModelResponse::ModelError("Unknown response format")
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
