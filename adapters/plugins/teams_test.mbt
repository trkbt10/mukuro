///|
/// Teams Plugin Tests

///|
test "TeamsPlugin::new creates empty plugin" {
  let config = TeamsPluginConfig::default(name="test-bot")
  let plugin = TeamsPlugin::new(config)
  inspect(plugin.is_connected, content="false")
  inspect(plugin.received_messages.length(), content="0")
}

///|
test "TeamsPlugin::connect and disconnect via RPC" {
  let config = TeamsPluginConfig::default(name="test-bot")
  let plugin = TeamsPlugin::new(config)
  // Connect via RPC
  let connect_request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "connect",
    params: None,
    id: Some(1),
  }
  let connect_response = plugin.handle_request(connect_request)
  match connect_response.result {
    Some({ "status": String(s), .. }) => inspect(s, content="connected")
    _ => fail("Expected status: connected")
  }
  // Disconnect via RPC
  let disconnect_request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "disconnect",
    params: None,
    id: Some(2),
  }
  let response = plugin.handle_request(disconnect_request)
  match response.result {
    Some({ "status": String(s), .. }) => inspect(s, content="disconnected")
    _ => fail("Expected status: disconnected")
  }
}

///|
test "TeamsPluginConfig::default" {
  let config = TeamsPluginConfig::default(name="my-bot")
  inspect(config.name, content="my-bot")
  inspect(config.bot_name, content="MukuroBot")
  inspect(config.bot_id, content="")
}

///|
test "AdaptiveCard::to_json basic" {
  let card : AdaptiveCard = {
    body: [
      {
        element_type: "TextBlock",
        text: "Hello",
        size: "Large",
        weight: "Bolder",
      },
    ],
    actions: [],
  }
  let json = card.to_json()
  match json {
    { "type": String(t), "version": String(v), .. } => {
      inspect(t, content="AdaptiveCard")
      inspect(v, content="1.4")
    }
    _ => fail("Expected AdaptiveCard")
  }
}

///|
test "AdaptiveCard::to_json with actions" {
  let card : AdaptiveCard = {
    body: [{ element_type: "TextBlock", text: "Choose", size: "", weight: "" }],
    actions: [
      { action_type: "Action.Submit", title: "OK", data: "ok_clicked" },
      {
        action_type: "Action.OpenUrl",
        title: "Visit",
        data: "https://example.com",
      },
    ],
  }
  let json = card.to_json()
  match json {
    { "actions": Array(actions), .. } => inspect(actions.length(), content="2")
    _ => fail("Expected actions array")
  }
}

///|
test "TeamsPlugin::receive empty returns None" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  inspect(plugin.receive() is None, content="true")
}

///|
test "TeamsPlugin::handle_activity message" {
  let config : TeamsPluginConfig = {
    name: "test",
    bot_id: "bot123",
    bot_name: "TestBot",
    tenant_id: "tenant123",
  }
  let plugin = TeamsPlugin::new(config)
  let activity : Json = {
    "type": "message",
    "id": "msg123",
    "text": "Hello Teams!",
    "conversation": { "id": "conv123" },
    "from": { "id": "user123", "name": "Test User" },
    "timestamp": "2023-01-01T00:00:00Z",
    "serviceUrl": "https://smba.trafficmanager.net/",
    "channelData": {
      "tenant": { "id": "tenant123" },
      "channel": { "id": "chan123" },
      "team": { "id": "team123" },
    },
  }
  let result = plugin.handle_activity(activity)
  match result {
    { "status": String(s), .. } => inspect(s, content="ok")
    _ => fail("Expected status ok")
  }
  // Message should be queued
  inspect(plugin.received_messages.length(), content="1")
}

///|
test "TeamsPlugin::receive from queue" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  // Process a message first
  let activity : Json = {
    "type": "message",
    "id": "msg123",
    "text": "Test message",
    "conversation": { "id": "conv123" },
    "from": { "id": "user123", "name": "Test User" },
    "timestamp": "2023-01-01T00:00:00Z",
    "serviceUrl": "https://smba.trafficmanager.net/",
    "channelData": {
      "tenant": { "id": "" },
      "channel": { "id": "" },
      "team": { "id": "" },
    },
  }
  let _ = plugin.handle_activity(activity)
  // Now receive
  match plugin.receive() {
    Some(msg) => {
      inspect(msg.text, content="Test message")
      inspect(msg.from_name, content="Test User")
    }
    None => fail("Expected message")
  }
  // Queue should be empty now
  inspect(plugin.receive() is None, content="true")
}

///|
test "TeamsPlugin::create_text_response" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  let reply_to : TeamsMessage = {
    id: "msg123",
    conversation_id: "conv123",
    channel_id: "chan123",
    team_id: "team123",
    from_id: "user123",
    from_name: "Test User",
    text: "Original",
    message_type: "message",
    timestamp: "2023-01-01T00:00:00Z",
    service_url: "https://smba.trafficmanager.net/",
    tenant_id: "tenant123",
  }
  let response = plugin.create_text_response(reply_to, "Hello back!")
  match response {
    { "type": String(t), "text": String(txt), .. } => {
      inspect(t, content="message")
      inspect(txt, content="Hello back!")
    }
    _ => fail("Expected message response")
  }
}

///|
test "TeamsPlugin::create_card_response" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  let reply_to : TeamsMessage = {
    id: "msg123",
    conversation_id: "conv123",
    channel_id: "chan123",
    team_id: "team123",
    from_id: "user123",
    from_name: "Test User",
    text: "Original",
    message_type: "message",
    timestamp: "2023-01-01T00:00:00Z",
    service_url: "https://smba.trafficmanager.net/",
    tenant_id: "tenant123",
  }
  let card : AdaptiveCard = {
    body: [
      { element_type: "TextBlock", text: "Card content", size: "", weight: "" },
    ],
    actions: [],
  }
  let response = plugin.create_card_response(reply_to, card)
  match response {
    { "type": String(t), "attachments": Array(att), .. } => {
      inspect(t, content="message")
      inspect(att.length(), content="1")
    }
    _ => fail("Expected card response")
  }
}

///|
test "TeamsPlugin::handle_request send" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  // First add a conversation
  let activity : Json = {
    "type": "message",
    "id": "msg123",
    "text": "Hi",
    "conversation": { "id": "conv123" },
    "from": { "id": "user123", "name": "Test User" },
    "timestamp": "2023-01-01T00:00:00Z",
    "serviceUrl": "https://smba.trafficmanager.net/",
    "channelData": {
      "tenant": { "id": "" },
      "channel": { "id": "" },
      "team": { "id": "" },
    },
  }
  let _ = plugin.handle_activity(activity)
  // Now send
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send",
    params: Some({ "conversation_id": "conv123", "text": "Reply" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "status": String(s), .. }) => inspect(s, content="pending")
    _ => fail("Expected pending status")
  }
}

///|
test "TeamsPlugin::handle_request send_card" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  // First add a conversation
  let activity : Json = {
    "type": "message",
    "id": "msg123",
    "text": "Hi",
    "conversation": { "id": "conv123" },
    "from": { "id": "user123", "name": "Test User" },
    "timestamp": "2023-01-01T00:00:00Z",
    "serviceUrl": "https://smba.trafficmanager.net/",
    "channelData": {
      "tenant": { "id": "" },
      "channel": { "id": "" },
      "team": { "id": "" },
    },
  }
  let _ = plugin.handle_activity(activity)
  // Now send card
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_card",
    params: Some({
      "conversation_id": "conv123",
      "body": [{ "type": "TextBlock", "text": "Hello" }],
      "actions": [],
    }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "status": String(s), .. }) => inspect(s, content="pending")
    _ => fail("Expected pending status")
  }
}

///|
test "TeamsPlugin::handle_request status" {
  let config : TeamsPluginConfig = {
    name: "test",
    bot_id: "bot123",
    bot_name: "TestBot",
    tenant_id: "",
  }
  let plugin = TeamsPlugin::new(config)
  // Connect first via RPC
  let connect_request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "connect",
    params: None,
    id: Some(0),
  }
  let _ = plugin.handle_request(connect_request)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "status",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "connected": True, "bot_id": String(b), .. }) =>
      inspect(b, content="bot123")
    _ => fail("Expected connected status")
  }
}

///|
test "TeamsPlugin::handle_request method not found" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
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
test "TeamsPlugin::handle_activity conversationUpdate" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  let activity : Json = {
    "type": "conversationUpdate",
    "membersAdded": [{ "id": "user123" }],
  }
  let result = plugin.handle_activity(activity)
  match result {
    { "status": String(s), .. } => inspect(s, content="ok")
    _ => fail("Expected status ok")
  }
}

///|
test "TeamsPlugin::handle_activity invoke" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  let activity : Json = {
    "type": "invoke",
    "name": "adaptiveCard/action",
    "value": { "action": { "data": "button_clicked" } },
  }
  let result = plugin.handle_activity(activity)
  match result {
    { "status": Number(s, ..), .. } => inspect(s.to_int(), content="200")
    _ => fail("Expected status 200")
  }
}

///|
test "TeamsPlugin::handle_activity unknown type" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  let activity : Json = { "type": "unknown" }
  let result = plugin.handle_activity(activity)
  match result {
    { "status": String(s), .. } => inspect(s, content="ignored")
    _ => fail("Expected status ignored")
  }
}

///|
test "TeamsPlugin::handle_request send missing params" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send",
    params: Some({ "conversation_id": "conv123" }), // missing text
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.error {
    Some(err) => inspect(err.code, content="-32602")
    None => fail("Expected error response")
  }
}
