///|
/// Telegram Plugin Tests

///|
test "TelegramPlugin::new creates empty plugin" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  inspect(plugin.is_connected(), content="false")
}

///|
test "TelegramPlugin::connect and disconnect" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  inspect(plugin.is_connected(), content="true")
  plugin.disconnect()
  inspect(plugin.is_connected(), content="false")
}

///|
test "TelegramPlugin::send_message" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  let result = plugin.send_message(12345L, "Hello!")
  match result {
    Object(obj) => {
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="sendMessage")
        _ => fail("Expected method in result")
      }
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("text") {
            Some(String(t)) => inspect(t, content="Hello!")
            _ => fail("Expected text in params")
          }
        _ => fail("Expected params in result")
      }
    }
    _ => fail("Expected object result")
  }
}

///|
test "TelegramPlugin::send_message with options" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  let result = plugin.send_message(
    12345L,
    "Hello!",
    reply_to_message_id=Some(100),
    parse_mode=Some("HTML"),
    disable_notification=true,
  )
  match result {
    Object(obj) =>
      match obj.get("params") {
        Some(Object(params)) => {
          match params.get("reply_to_message_id") {
            Some(Number(n, ..)) => inspect(n.to_int(), content="100")
            _ => fail("Expected reply_to_message_id")
          }
          match params.get("parse_mode") {
            Some(String(m)) => inspect(m, content="HTML")
            _ => fail("Expected parse_mode")
          }
          match params.get("disable_notification") {
            Some(True) => ()
            _ => fail("Expected disable_notification")
          }
        }
        _ => fail("Expected params")
      }
    _ => fail("Expected object result")
  }
}

///|
test "TelegramPlugin::send_photo" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  let result = plugin.send_photo(
    12345L,
    "https://example.com/photo.jpg",
    caption=Some("Nice photo!"),
  )
  match result {
    Object(obj) =>
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="sendPhoto")
        _ => fail("Expected method")
      }
    _ => fail("Expected object result")
  }
}

///|
test "TelegramPlugin::send_location" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  let result = plugin.send_location(12345L, 35.6762, 139.6503)
  match result {
    Object(obj) =>
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="sendLocation")
        _ => fail("Expected method")
      }
    _ => fail("Expected object result")
  }
}

///|
test "TelegramPlugin::edit_message" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  let result = plugin.edit_message(12345L, 100, "Updated text")
  match result {
    Object(obj) =>
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="editMessageText")
        _ => fail("Expected method")
      }
    _ => fail("Expected object result")
  }
}

///|
test "TelegramPlugin::delete_message" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  let result = plugin.delete_message(12345L, 100)
  match result {
    Object(obj) =>
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="deleteMessage")
        _ => fail("Expected method")
      }
    _ => fail("Expected object result")
  }
}

///|
test "TelegramPlugin::process_webhook parses message" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  let update : Json = {
    "update_id": 123456789,
    "message": {
      "message_id": 100,
      "from": {
        "id": 12345,
        "is_bot": false,
        "first_name": "John",
        "last_name": "Doe",
        "username": "johndoe",
      },
      "chat": { "id": 12345, "first_name": "John", "type": "private" },
      "date": 1234567890,
      "text": "Hello bot!",
    },
  }
  match plugin.process_webhook(update) {
    Some(msg) => {
      inspect(msg.message_id, content="100")
      inspect(msg.chat_id, content="12345")
      inspect(msg.text, content="Hello bot!")
      inspect(msg.from_name, content="John Doe")
    }
    None => fail("Expected to parse message")
  }
}

///|
test "TelegramPlugin::receive from buffer" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  // Add a message to the buffer
  let msg : TelegramMessage = {
    message_id: 1,
    chat_id: 12345L,
    from_id: Some(67890L),
    from_username: Some("testuser"),
    from_name: "Test User",
    message_type: TelegramMessageType::Text,
    text: "Hello!",
    caption: None,
    photo: None,
    document: None,
    reply_to_message_id: None,
    timestamp: 1000L,
  }
  plugin.add_received_message(msg)
  // Receive the message
  match plugin.receive() {
    Some(received) => {
      inspect(received.text, content="Hello!")
      inspect(received.from_name, content="Test User")
    }
    None => fail("Expected to receive message")
  }
  // Buffer should be empty now
  match plugin.receive() {
    Some(_) => fail("Expected empty buffer")
    None => ()
  }
}

///|
test "TelegramPlugin::handle_request send_message" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_message",
    params: Some({ "chat_id": 12345, "text": "Hello from RPC!" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some(Object(obj)) =>
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="sendMessage")
        _ => fail("Expected method")
      }
    _ => fail("Expected result")
  }
}

///|
test "TelegramPlugin::handle_request status" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
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
test "TelegramPlugin::handle_request method not found" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
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
test "TelegramPlugin::send_inline_keyboard" {
  let config = TelegramPluginConfig::default(
    name="test-bot",
    bot_token="123456:ABC-DEF",
  )
  let plugin = TelegramPlugin::new(config)
  plugin.connect()
  let keyboard : Array[Array[TelegramInlineButton]] = [
    [
      { text: "Button 1", callback_data: Some("btn1"), url: None },
      { text: "Button 2", callback_data: Some("btn2"), url: None },
    ],
  ]
  let result = plugin.send_inline_keyboard(12345L, "Choose:", keyboard)
  match result {
    Object(obj) => {
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="sendMessage")
        _ => fail("Expected method")
      }
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("reply_markup") {
            Some(Object(_)) => ()
            _ => fail("Expected reply_markup")
          }
        _ => fail("Expected params")
      }
    }
    _ => fail("Expected object result")
  }
}
