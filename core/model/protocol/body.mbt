///|
/// OpenAI Chat Completionsリクエストボディを構築
pub fn build_openai_chat_body(
  model : String,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  max_tokens? : Int? = None,
  temperature? : Double? = None,
) -> Json {
  let msgs = messages_to_openai_json(messages)
  let mut body : Json = { "model": model, "messages": Json::array(msgs) }
  match max_tokens {
    Some(max) =>
      body = set_json_field(body, "max_tokens", Json::number(max.to_double()))
    None => ()
  }
  match temperature {
    Some(temp) => body = set_json_field(body, "temperature", Json::number(temp))
    None => ()
  }
  if tools.length() > 0 {
    body = set_json_field(
      body,
      "tools",
      Json::array(tools_to_openai_json(tools)),
    )
    body = set_json_field(body, "tool_choice", Json::string("auto"))
  }
  body
}

///|
/// OpenAI Responses APIリクエストボディを構築
pub fn build_responses_api_body(
  model : String,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
) -> Json {
  let input = messages_to_responses_input(messages)
  if tools.length() > 0 {
    {
      "model": model,
      "input": Json::array(input),
      "tools": Json::array(tools_to_responses_api_json(tools)),
      "tool_choice": "auto",
    }
  } else {
    { "model": model, "input": Json::array(input) }
  }
}

///|
/// Anthropicリクエストボディを構築
pub fn build_anthropic_body(
  model : String,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  max_tokens? : Int? = None,
  system? : String = "",
  temperature? : Double? = None,
) -> Json {
  let system_msg = if system.length() > 0 {
    system
  } else {
    extract_system_message(messages)
  }
  let msgs = messages_to_anthropic_json(messages)
  // Anthropic API requires max_tokens
  let effective_max_tokens = max_tokens.or(8192)
  let mut body : Json = {
    "model": model,
    "max_tokens": effective_max_tokens,
    "messages": Json::array(msgs),
  }
  if system_msg.length() > 0 {
    body = set_json_field(body, "system", Json::string(system_msg))
  }
  match temperature {
    Some(temp) => body = set_json_field(body, "temperature", Json::number(temp))
    None => ()
  }
  if tools.length() > 0 {
    body = set_json_field(
      body,
      "tools",
      Json::array(tools_to_anthropic_json(tools)),
    )
  }
  body
}

///|
/// JSONにフィールドを設定するヘルパー
fn set_json_field(json : Json, key : String, value : Json) -> Json {
  match json {
    Object(map) => {
      map[key] = value
      Json::object(map)
    }
    _ => json
  }
}
