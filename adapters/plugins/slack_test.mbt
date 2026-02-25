///|
/// Slack Plugin Tests

///|
test "SlackPlugin::new creates empty plugin" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  inspect(plugin.is_connected(), content="false")
}

///|
test "SlackPlugin::connect and disconnect" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  inspect(plugin.is_connected(), content="true")
  plugin.disconnect()
  inspect(plugin.is_connected(), content="false")
}

///|
test "SlackPlugin::send_message" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let result = plugin.send_message("C12345", "Hello Slack!")
  match result {
    Object(obj) => {
      match obj.get("api_method") {
        Some(String(m)) => inspect(m, content="chat.postMessage")
        _ => fail("Expected api_method")
      }
      match obj.get("params") {
        Some(Object(params)) => {
          match params.get("text") {
            Some(String(t)) => inspect(t, content="Hello Slack!")
            _ => fail("Expected text")
          }
          match params.get("channel") {
            Some(String(c)) => inspect(c, content="C12345")
            _ => fail("Expected channel")
          }
        }
        _ => fail("Expected params")
      }
    }
    _ => fail("Expected object result")
  }
}

///|
test "SlackPlugin::send_message with thread" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let result = plugin.send_message(
    "C12345",
    "Reply!",
    thread_ts=Some("1234567890.123456"),
  )
  match result {
    Object(obj) =>
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("thread_ts") {
            Some(String(t)) => inspect(t, content="1234567890.123456")
            _ => fail("Expected thread_ts")
          }
        _ => fail("Expected params")
      }
    _ => fail("Expected object result")
  }
}

///|
test "SlackPlugin::send_blocks" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let block : SlackBlock = {
    block_type: "section",
    block_id: Some("section1"),
    text: Some({ text_type: "mrkdwn", text: "*Hello*", emoji: false }),
    accessory: None,
    elements: None,
  }
  let result = plugin.send_blocks("C12345", [block], text=Some("Fallback text"))
  match result {
    Object(obj) =>
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("blocks") {
            Some(Array(arr)) => inspect(arr.length(), content="1")
            _ => fail("Expected blocks array")
          }
        _ => fail("Expected params")
      }
    _ => fail("Expected object result")
  }
}

///|
test "SlackPlugin::update_message" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let result = plugin.update_message(
    "C12345", "1234567890.123456", "Updated text",
  )
  match result {
    Object(obj) =>
      match obj.get("api_method") {
        Some(String(m)) => inspect(m, content="chat.update")
        _ => fail("Expected api_method")
      }
    _ => fail("Expected object result")
  }
}

///|
test "SlackPlugin::delete_message" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let result = plugin.delete_message("C12345", "1234567890.123456")
  match result {
    Object(obj) =>
      match obj.get("api_method") {
        Some(String(m)) => inspect(m, content="chat.delete")
        _ => fail("Expected api_method")
      }
    _ => fail("Expected object result")
  }
}

///|
test "SlackPlugin::add_reaction" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let result = plugin.add_reaction("C12345", "1234567890.123456", "thumbsup")
  match result {
    Object(obj) => {
      match obj.get("api_method") {
        Some(String(m)) => inspect(m, content="reactions.add")
        _ => fail("Expected api_method")
      }
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("name") {
            Some(String(n)) => inspect(n, content="thumbsup")
            _ => fail("Expected name")
          }
        _ => fail("Expected params")
      }
    }
    _ => fail("Expected object result")
  }
}

///|
test "SlackPlugin::upload_file" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let result = plugin.upload_file(
    ["C12345", "C67890"],
    "File content here",
    filename="test.txt",
    title=Some("Test File"),
  )
  match result {
    Object(obj) =>
      match obj.get("api_method") {
        Some(String(m)) => inspect(m, content="files.upload")
        _ => fail("Expected api_method")
      }
    _ => fail("Expected object result")
  }
}

///|
test "SlackPlugin::process_event parses message" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let event : Json = {
    "token": "abc123",
    "team_id": "T12345",
    "event": {
      "type": "message",
      "user": "U12345",
      "text": "Hello from Slack!",
      "ts": "1234567890.123456",
      "channel": "C12345",
      "event_ts": "1234567890.123456",
    },
    "type": "event_callback",
  }
  match plugin.process_event(event) {
    Some(msg) => {
      inspect(msg.text, content="Hello from Slack!")
      inspect(msg.user_id, content="U12345")
      inspect(msg.channel_id, content="C12345")
      inspect(msg.ts, content="1234567890.123456")
    }
    None => fail("Expected to parse message")
  }
}

///|
test "SlackPlugin::receive from buffer" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let msg : SlackMessage = {
    client_msg_id: Some("msg123"),
    text: "Hello!",
    user_id: "U12345",
    user_name: "Test User",
    channel_id: "C12345",
    ts: "1234567890.123456",
    thread_ts: None,
    blocks: None,
    bot_id: None,
    subtype: None,
  }
  plugin.add_received_message(msg)
  match plugin.receive() {
    Some(received) => {
      inspect(received.text, content="Hello!")
      inspect(received.user_id, content="U12345")
    }
    None => fail("Expected to receive message")
  }
}

///|
test "SlackPlugin::handle_request send_message" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_message",
    params: Some({ "channel": "C12345", "text": "Hello from RPC!" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some(Object(obj)) =>
      match obj.get("api_method") {
        Some(String(m)) => inspect(m, content="chat.postMessage")
        _ => fail("Expected api_method")
      }
    _ => fail("Expected result")
  }
}

///|
test "SlackPlugin::handle_request status" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "status",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "connected": True, "pending_messages": Number(_), .. }) => ()
    _ => fail("Expected connected status")
  }
}

///|
test "SlackPlugin::handle_request method not found" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "unknown_method",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.error {
    Some(err) => inspect(err.code, content="-32601")
    None => fail("Expected error response")
  }
}

///|
test "SlackPlugin::process_interaction" {
  let config = SlackPluginConfig::default(
    name="test-bot",
    bot_token="xoxb-test-token",
    signing_secret="test-secret",
  )
  let plugin = SlackPlugin::new(config)
  plugin.connect()
  let payload : Json = {
    "type": "block_actions",
    "user": { "id": "U12345", "username": "testuser" },
    "channel": { "id": "C12345" },
    "actions": [{ "action_id": "btn_click", "value": "clicked" }],
  }
  match plugin.process_interaction(payload) {
    Some(Object(result)) => {
      match result.get("interaction_type") {
        Some(String(t)) => inspect(t, content="block_actions")
        _ => fail("Expected interaction_type")
      }
      match result.get("user_id") {
        Some(String(u)) => inspect(u, content="U12345")
        _ => fail("Expected user_id")
      }
      match result.get("action_id") {
        Some(String(a)) => inspect(a, content="btn_click")
        _ => fail("Expected action_id")
      }
    }
    _ => fail("Expected object result")
  }
}
