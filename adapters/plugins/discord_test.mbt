///|
/// Discord Plugin Tests

///|
test "DiscordPlugin::new creates empty plugin" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  inspect(plugin.is_connected(), content="false")
}

///|
test "DiscordPlugin::connect and disconnect" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  inspect(plugin.is_connected(), content="true")
  plugin.disconnect()
  inspect(plugin.is_connected(), content="false")
}

///|
test "DiscordPlugin::send_message" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let result = plugin.send_message("channel123", "Hello Discord!")
  match result {
    Object(obj) => {
      match obj.get("endpoint") {
        Some(String(e)) => inspect(e, content="sendMessage")
        _ => fail("Expected endpoint")
      }
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("content") {
            Some(String(c)) => inspect(c, content="Hello Discord!")
            _ => fail("Expected content")
          }
        _ => fail("Expected params")
      }
    }
    _ => fail("Expected object result")
  }
}

///|
test "DiscordPlugin::send_message with reply" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let result = plugin.send_message(
    "channel123",
    "Reply!",
    reply_to=Some("msg456"),
  )
  match result {
    Object(obj) =>
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("message_reference") {
            Some(Object(ref_obj)) =>
              match ref_obj.get("message_id") {
                Some(String(m)) => inspect(m, content="msg456")
                _ => fail("Expected message_id")
              }
            _ => fail("Expected message_reference")
          }
        _ => fail("Expected params")
      }
    _ => fail("Expected object result")
  }
}

///|
test "DiscordPlugin::send_embed" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let embed : DiscordEmbed = {
    title: Some("Test Title"),
    description: Some("Test Description"),
    url: None,
    color: Some(0xFF0000),
    fields: None,
    footer_text: None,
    thumbnail_url: None,
    image_url: None,
  }
  let result = plugin.send_embed("channel123", [embed])
  match result {
    Object(obj) =>
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("embeds") {
            Some(Array(arr)) => inspect(arr.length(), content="1")
            _ => fail("Expected embeds array")
          }
        _ => fail("Expected params")
      }
    _ => fail("Expected object result")
  }
}

///|
test "DiscordPlugin::edit_message" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let result = plugin.edit_message("channel123", "msg456", "Updated content")
  match result {
    Object(obj) => {
      match obj.get("endpoint") {
        Some(String(e)) => inspect(e, content="editMessage")
        _ => fail("Expected endpoint")
      }
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="PATCH")
        _ => fail("Expected method")
      }
    }
    _ => fail("Expected object result")
  }
}

///|
test "DiscordPlugin::delete_message" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let result = plugin.delete_message("channel123", "msg456")
  match result {
    Object(obj) => {
      match obj.get("endpoint") {
        Some(String(e)) => inspect(e, content="deleteMessage")
        _ => fail("Expected endpoint")
      }
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="DELETE")
        _ => fail("Expected method")
      }
    }
    _ => fail("Expected object result")
  }
}

///|
test "DiscordPlugin::add_reaction" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let result = plugin.add_reaction("channel123", "msg456", "thumbsup")
  match result {
    Object(obj) =>
      match obj.get("endpoint") {
        Some(String(e)) => inspect(e, content="addReaction")
        _ => fail("Expected endpoint")
      }
    _ => fail("Expected object result")
  }
}

///|
test "DiscordPlugin::process_gateway_event parses message" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let event : Json = {
    "t": "MESSAGE_CREATE",
    "s": 1,
    "op": 0,
    "d": {
      "id": "123456789012345678",
      "channel_id": "987654321098765432",
      "author": {
        "id": "111222333444555666",
        "username": "testuser",
        "discriminator": "1234",
        "bot": false,
      },
      "content": "Hello from Discord!",
      "timestamp": "2023-01-01T00:00:00.000Z",
      "type": 0,
    },
  }
  match plugin.process_gateway_event(event) {
    Some(msg) => {
      inspect(msg.id, content="123456789012345678")
      inspect(msg.channel_id, content="987654321098765432")
      inspect(msg.content, content="Hello from Discord!")
      inspect(msg.author_name, content="testuser")
    }
    None => fail("Expected to parse message")
  }
}

///|
test "DiscordPlugin::receive from buffer" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let msg : DiscordMessage = {
    id: "123",
    channel_id: "456",
    guild_id: Some("789"),
    author_id: "111",
    author_name: "Test User",
    author_discriminator: "0001",
    author_avatar: None,
    author_is_bot: false,
    content: "Hello!",
    message_type: DiscordMessageType::Default,
    embeds: None,
    attachments: None,
    referenced_message_id: None,
    timestamp: "2023-01-01T00:00:00Z",
  }
  plugin.add_received_message(msg)
  match plugin.receive() {
    Some(received) => {
      inspect(received.content, content="Hello!")
      inspect(received.author_name, content="Test User")
    }
    None => fail("Expected to receive message")
  }
}

///|
test "DiscordPlugin::handle_request send_message" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_message",
    params: Some({ "channel_id": "channel123", "content": "Hello from RPC!" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some(Object(obj)) =>
      match obj.get("endpoint") {
        Some(String(e)) => inspect(e, content="sendMessage")
        _ => fail("Expected endpoint")
      }
    _ => fail("Expected result")
  }
}

///|
test "DiscordPlugin::handle_request status" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "status",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "connected": True, "application_id": String(_), .. }) => ()
    _ => fail("Expected connected status")
  }
}

///|
test "DiscordPlugin::handle_request method not found" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
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
test "DiscordPlugin::send_with_buttons" {
  let config = DiscordPluginConfig::default(
    name="test-bot",
    bot_token="test-token",
    application_id="123456789",
  )
  let plugin = DiscordPlugin::new(config)
  plugin.connect()
  let buttons : Array[DiscordButton] = [
    {
      style: DiscordButtonStyle::Primary,
      label: "Click me",
      custom_id: Some("btn1"),
      url: None,
      disabled: false,
      emoji: None,
    },
  ]
  let result = plugin.send_with_buttons("channel123", "Choose:", buttons)
  match result {
    Object(obj) =>
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("components") {
            Some(Array(arr)) => inspect(arr.length(), content="1")
            _ => fail("Expected components array")
          }
        _ => fail("Expected params")
      }
    _ => fail("Expected object result")
  }
}
