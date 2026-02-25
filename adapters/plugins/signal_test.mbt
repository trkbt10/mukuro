///|
/// Signal Plugin Tests

///|
test "SignalPlugin::new creates empty plugin" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  inspect(plugin.received_messages.length(), content="0")
  inspect(plugin.is_connected, content="false")
}

///|
test "SignalPluginConfig::default" {
  let config = SignalPluginConfig::default(name="my-signal")
  inspect(config.name, content="my-signal")
  inspect(config.phone_number, content="")
  inspect(config.socket_path, content="/var/run/signal-cli/socket")
  inspect(config.trust_all, content="false")
}

///|
test "SignalPlugin::create_send_command basic" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let cmd = plugin.create_send_command("+0987654321", "Hello Signal!")
  match cmd {
    { "method": String(m), "params": { "message": String(msg), .. }, .. } => {
      inspect(m, content="send")
      inspect(msg, content="Hello Signal!")
    }
    _ => fail("Expected send command")
  }
}

///|
test "SignalPlugin::create_send_command to group" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let cmd = plugin.create_send_command("group123", "Hello Group!")
  match cmd {
    { "params": { "groupId": String(gid), .. }, .. } =>
      inspect(gid, content="group123")
    _ => fail("Expected groupId in params")
  }
}

///|
test "SignalPlugin::create_send_command with attachments" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let cmd = plugin.create_send_command("+0987654321", "With attachment", attachments=[
    "/path/to/file.jpg",
  ])
  match cmd {
    { "params": { "attachments": Array(att), .. }, .. } =>
      inspect(att.length(), content="1")
    _ => fail("Expected attachments in params")
  }
}

///|
test "SignalPlugin::create_send_command with quote" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let quote : SignalQuote = {
    timestamp: 1234567890L,
    author: "+1111111111",
    text: "Original message",
  }
  let cmd = plugin.create_send_command(
    "+0987654321",
    "Reply",
    quote=Some(quote),
  )
  match cmd {
    { "params": { "quote": { "author": String(a), .. }, .. }, .. } =>
      inspect(a, content="+1111111111")
    _ => fail("Expected quote in params")
  }
}

///|
test "SignalPlugin::create_send_command with mentions" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let mentions : Array[SignalMention] = [
    { start: 0, length: 5, uuid: "uuid-123" },
  ]
  let cmd = plugin.create_send_command("+0987654321", "@User hello", mentions~)
  match cmd {
    { "params": { "mentions": Array(m), .. }, .. } =>
      inspect(m.length(), content="1")
    _ => fail("Expected mentions in params")
  }
}

///|
test "SignalPlugin::create_reaction_command" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let cmd = plugin.create_reaction_command(
    "+0987654321", "👍", "+1111111111", 1234567890L,
  )
  match cmd {
    { "method": String(m), "params": { "emoji": String(e), .. }, .. } => {
      inspect(m, content="sendReaction")
      inspect(e, content="👍")
    }
    _ => fail("Expected sendReaction command")
  }
}

///|
test "SignalPlugin::create_reaction_command remove" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let cmd = plugin.create_reaction_command(
    "+0987654321",
    "👍",
    "+1111111111",
    1234567890L,
    remove=true,
  )
  match cmd {
    { "params": { "remove": True, .. }, .. } => ()
    _ => fail("Expected remove: true in params")
  }
}

///|
test "SignalPlugin::handle_incoming with data message" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let incoming : Json = {
    "envelope": {
      "source": "+1111111111",
      "timestamp": 1234567890.0,
      "dataMessage": { "message": "Hello!", "timestamp": 1234567890.0 },
    },
  }
  let result = plugin.handle_incoming(incoming)
  match result {
    { "status": String(s), .. } => inspect(s, content="ok")
    _ => fail("Expected status ok")
  }
  inspect(plugin.received_messages.length(), content="1")
}

///|
test "SignalPlugin::handle_incoming with group message" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let incoming : Json = {
    "envelope": {
      "source": "+1111111111",
      "timestamp": 1234567890.0,
      "dataMessage": {
        "message": "Group hello!",
        "groupInfo": { "groupId": "group123" },
      },
    },
  }
  let _ = plugin.handle_incoming(incoming)
  match plugin.receive() {
    Some(msg) => {
      inspect(msg.is_group, content="true")
      match msg.group_id {
        Some(gid) => inspect(gid, content="group123")
        None => fail("Expected group_id")
      }
    }
    None => fail("Expected message")
  }
}

///|
test "SignalPlugin::handle_incoming with reaction" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let incoming : Json = {
    "envelope": {
      "source": "+1111111111",
      "timestamp": 1234567890.0,
      "dataMessage": {
        "reaction": {
          "emoji": "❤️",
          "targetSentTimestamp": 1234567800.0,
          "targetAuthor": "+2222222222",
        },
      },
    },
  }
  let _ = plugin.handle_incoming(incoming)
  match plugin.receive() {
    Some(msg) =>
      match msg.reaction {
        Some(r) => {
          inspect(r.emoji, content="❤️")
          inspect(r.target_author, content="+2222222222")
        }
        None => fail("Expected reaction")
      }
    None => fail("Expected message")
  }
}

///|
test "SignalPlugin::handle_incoming with attachments" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let incoming : Json = {
    "envelope": {
      "source": "+1111111111",
      "timestamp": 1234567890.0,
      "dataMessage": {
        "message": "Photo",
        "attachments": [
          {
            "contentType": "image/jpeg",
            "filename": "photo.jpg",
            "id": "att1",
            "size": 12345.0,
          },
        ],
      },
    },
  }
  let _ = plugin.handle_incoming(incoming)
  match plugin.receive() {
    Some(msg) => {
      inspect(msg.attachments.length(), content="1")
      inspect(msg.attachments[0].content_type, content="image/jpeg")
    }
    None => fail("Expected message")
  }
}

///|
test "SignalPlugin::receive empty returns None" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  inspect(plugin.receive() is None, content="true")
}

///|
test "SignalPlugin::receive from queue" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let incoming : Json = {
    "envelope": {
      "source": "+1111111111",
      "timestamp": 1234567890.0,
      "dataMessage": { "message": "Test message" },
    },
  }
  let _ = plugin.handle_incoming(incoming)
  match plugin.receive() {
    Some(msg) => {
      inspect(msg.text, content="Test message")
      inspect(msg.sender, content="+1111111111")
    }
    None => fail("Expected message")
  }
  inspect(plugin.receive() is None, content="true")
}

///|
test "SignalPlugin::handle_request send" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send",
    params: Some({ "recipient": "+0987654321", "text": "Hello" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "status": String(s), "command": Object(_), .. }) =>
      inspect(s, content="pending")
    _ => fail("Expected pending status with command")
  }
}

///|
test "SignalPlugin::handle_request send with 'to' param" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send",
    params: Some({ "to": "+0987654321", "text": "Hello" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "status": String(s), .. }) => inspect(s, content="pending")
    _ => fail("Expected pending status")
  }
}

///|
test "SignalPlugin::handle_request send missing params" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send",
    params: Some({ "recipient": "+0987654321" }), // missing text
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.error {
    Some(err) => inspect(err.code, content="-32602")
    None => fail("Expected error response")
  }
}

///|
test "SignalPlugin::handle_request send_reaction" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_reaction",
    params: Some({
      "recipient": "+0987654321",
      "emoji": "👍",
      "target_author": "+1111111111",
      "target_timestamp": 1234567890.0,
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
test "SignalPlugin::handle_request incoming" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "incoming",
    params: Some({
      "envelope": {
        "source": "+1111111111",
        "timestamp": 1234567890.0,
        "dataMessage": { "message": "Test" },
      },
    }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "status": String(s), .. }) => inspect(s, content="ok")
    _ => fail("Expected status ok")
  }
}

///|
test "SignalPlugin::handle_request receive" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  // First add a message
  let incoming : Json = {
    "envelope": {
      "source": "+1111111111",
      "timestamp": 1234567890.0,
      "dataMessage": { "message": "Test message" },
    },
  }
  let _ = plugin.handle_incoming(incoming)
  // Now receive
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "receive",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "text": String(t), "sender": String(s), .. }) => {
      inspect(t, content="Test message")
      inspect(s, content="+1111111111")
    }
    _ => fail("Expected message result")
  }
}

///|
test "SignalPlugin::handle_request receive empty" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "receive",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "message": Null, .. }) => ()
    _ => fail("Expected null message")
  }
}

///|
test "SignalPlugin::handle_request status" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/socket",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  // Connect first
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
    Some({ "connected": True, "phone_number": String(p), .. }) =>
      inspect(p, content="+1234567890")
    _ => fail("Expected connected status")
  }
}

///|
test "SignalPlugin::handle_request connect" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "connect",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "status": String(s), .. }) => inspect(s, content="connected")
    _ => fail("Expected status: connected")
  }
}

///|
test "SignalPlugin::handle_request disconnect" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  // Connect first
  let connect_request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "connect",
    params: None,
    id: Some(0),
  }
  let _ = plugin.handle_request(connect_request)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "disconnect",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "status": String(s), .. }) => inspect(s, content="disconnected")
    _ => fail("Expected status: disconnected")
  }
}

///|
test "SignalPlugin::handle_request method not found" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
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
test "SignalPlugin::handle_incoming with sync message" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  let incoming : Json = {
    "envelope": {
      "source": "+1234567890",
      "timestamp": 1234567890.0,
      "syncMessage": {
        "sentMessage": {
          "destination": "+0987654321",
          "message": "Synced message",
        },
      },
    },
  }
  let _ = plugin.handle_incoming(incoming)
  match plugin.receive() {
    Some(msg) => inspect(msg.text, content="Synced message")
    None => fail("Expected message")
  }
}
