///|
/// WhatsApp Plugin Tests

///|
test "WhatsAppPlugin::new creates empty plugin" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  inspect(plugin.received_messages.length(), content="0")
  inspect(plugin.is_connected, content="false")
}

///|
test "WhatsAppPluginConfig::default" {
  let config = WhatsAppPluginConfig::default(name="my-whatsapp")
  inspect(config.name, content="my-whatsapp")
  inspect(config.phone_number_id, content="")
  inspect(config.business_account_id, content="")
  inspect(config.api_version, content="v18.0")
  inspect(config.verify_token, content="")
}

///|
test "WhatsAppPlugin::create_text_message" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let msg = plugin.create_text_message("+1234567890", "Hello WhatsApp!")
  match msg {
    {
      "messaging_product": String(mp),
      "to": String(to),
      "type": String(t),
      "text": { "body": String(body), .. },
      ..
    } => {
      inspect(mp, content="whatsapp")
      inspect(to, content="+1234567890")
      inspect(t, content="text")
      inspect(body, content="Hello WhatsApp!")
    }
    _ => fail("Expected text message")
  }
}

///|
test "WhatsAppPlugin::create_image_message" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let msg = plugin.create_image_message(
    "+1234567890", "https://example.com/image.jpg",
  )
  match msg {
    { "type": String(t), "image": { "link": String(url), .. }, .. } => {
      inspect(t, content="image")
      inspect(url, content="https://example.com/image.jpg")
    }
    _ => fail("Expected image message")
  }
}

///|
test "WhatsAppPlugin::create_image_message with caption" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let msg = plugin.create_image_message(
    "+1234567890",
    "https://example.com/image.jpg",
    caption="Check this out!",
  )
  match msg {
    { "image": { "caption": String(cap), .. }, .. } =>
      inspect(cap, content="Check this out!")
    _ => fail("Expected caption in image")
  }
}

///|
test "WhatsAppPlugin::create_document_message" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let msg = plugin.create_document_message(
    "+1234567890", "https://example.com/doc.pdf", "document.pdf",
  )
  match msg {
    {
      "type": String(t),
      "document": { "filename": String(fname), "link": String(url), .. },
      ..
    } => {
      inspect(t, content="document")
      inspect(fname, content="document.pdf")
      inspect(url, content="https://example.com/doc.pdf")
    }
    _ => fail("Expected document message")
  }
}

///|
test "WhatsAppPlugin::create_location_message" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let msg = plugin.create_location_message(
    "+1234567890",
    37.7749,
    -122.4194,
    name="San Francisco",
    address="California, USA",
  )
  match msg {
    {
      "type": String(t),
      "location": { "name": String(n), "address": String(a), .. },
      ..
    } => {
      inspect(t, content="location")
      inspect(n, content="San Francisco")
      inspect(a, content="California, USA")
    }
    _ => fail("Expected location message")
  }
}

///|
test "WhatsAppPlugin::create_buttons_message" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let buttons : Array[WhatsAppButton] = [
    { id: "btn1", title: "Yes" },
    { id: "btn2", title: "No" },
  ]
  let msg = plugin.create_buttons_message(
    "+1234567890", "Do you agree?", buttons,
  )
  match msg {
    { "type": String(t), "interactive": { "type": String(it), .. }, .. } => {
      inspect(t, content="interactive")
      inspect(it, content="button")
    }
    _ => fail("Expected interactive message")
  }
}

///|
test "WhatsAppPlugin::create_buttons_message with header and footer" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let buttons : Array[WhatsAppButton] = [{ id: "btn1", title: "OK" }]
  let msg = plugin.create_buttons_message(
    "+1234567890",
    "Body text",
    buttons,
    header="Header",
    footer="Footer",
  )
  match msg {
    {
      "interactive": {
        "header": { "text": String(h), .. },
        "footer": { "text": String(f), .. },
        ..
      },
      ..
    } => {
      inspect(h, content="Header")
      inspect(f, content="Footer")
    }
    _ => fail("Expected header and footer")
  }
}

///|
test "WhatsAppPlugin::create_template_message" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let template : WhatsAppTemplate = {
    name: "hello_world",
    language: "en_US",
    components: [],
  }
  let msg = plugin.create_template_message("+1234567890", template)
  match msg {
    {
      "type": String(t),
      "template": {
        "name": String(n),
        "language": { "code": String(l), .. },
        ..
      },
      ..
    } => {
      inspect(t, content="template")
      inspect(n, content="hello_world")
      inspect(l, content="en_US")
    }
    _ => fail("Expected template message")
  }
}

///|
test "WhatsAppPlugin::handle_webhook verification" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let payload : Json = {
    "hub.mode": "subscribe",
    "hub.challenge": "challenge_token_123",
    "hub.verify_token": "my_verify_token",
  }
  let result = plugin.handle_webhook(payload)
  match result {
    { "challenge": String(c), .. } => inspect(c, content="challenge_token_123")
    _ => fail("Expected challenge response")
  }
}

///|
test "WhatsAppPlugin::handle_webhook text message" {
  let config : WhatsAppPluginConfig = {
    name: "test",
    phone_number_id: "123456",
    business_account_id: "789",
    api_version: "v18.0",
    verify_token: "token",
  }
  let plugin = WhatsAppPlugin::new(config)
  let payload : Json = {
    "entry": [
      {
        "changes": [
          {
            "value": {
              "messages": [
                {
                  "id": "msg123",
                  "from": "+1234567890",
                  "timestamp": "1234567890",
                  "type": "text",
                  "text": { "body": "Hello!" },
                },
              ],
            },
          },
        ],
      },
    ],
  }
  let result = plugin.handle_webhook(payload)
  match result {
    { "status": String(s), .. } => inspect(s, content="ok")
    _ => fail("Expected status ok")
  }
  inspect(plugin.received_messages.length(), content="1")
}

///|
test "WhatsAppPlugin::handle_webhook status update" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let payload : Json = {
    "entry": [
      {
        "changes": [
          {
            "value": { "statuses": [{ "id": "msg123", "status": "delivered" }] },
          },
        ],
      },
    ],
  }
  let _ = plugin.handle_webhook(payload)
  match plugin.status_updates.get("msg123") {
    Some(status) => inspect(status, content="delivered")
    None => fail("Expected status update")
  }
}

///|
test "WhatsAppPlugin::receive empty returns None" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  inspect(plugin.receive() is None, content="true")
}

///|
test "WhatsAppPlugin::receive from queue" {
  let config : WhatsAppPluginConfig = {
    name: "test",
    phone_number_id: "123456",
    business_account_id: "789",
    api_version: "v18.0",
    verify_token: "token",
  }
  let plugin = WhatsAppPlugin::new(config)
  let payload : Json = {
    "entry": [
      {
        "changes": [
          {
            "value": {
              "messages": [
                {
                  "id": "msg123",
                  "from": "+1234567890",
                  "timestamp": "1234567890",
                  "type": "text",
                  "text": { "body": "Test message" },
                },
              ],
            },
          },
        ],
      },
    ],
  }
  let _ = plugin.handle_webhook(payload)
  match plugin.receive() {
    Some(msg) => {
      inspect(msg.text, content="Test message")
      inspect(msg.from, content="+1234567890")
    }
    None => fail("Expected message")
  }
  inspect(plugin.receive() is None, content="true")
}

///|
test "WhatsAppPlugin::handle_request send_text" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_text",
    params: Some({ "to": "+1234567890", "text": "Hello" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "status": String(s), "payload": Object(_), .. }) =>
      inspect(s, content="pending")
    _ => fail("Expected pending status with payload")
  }
}

///|
test "WhatsAppPlugin::handle_request send_text missing params" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_text",
    params: Some({ "to": "+1234567890" }), // missing text
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.error {
    Some(err) => inspect(err.code, content="-32602")
    None => fail("Expected error response")
  }
}

///|
test "WhatsAppPlugin::handle_request send_image" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_image",
    params: Some({
      "to": "+1234567890",
      "url": "https://example.com/image.jpg",
      "caption": "Nice photo",
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
test "WhatsAppPlugin::handle_request send_document" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_document",
    params: Some({
      "to": "+1234567890",
      "url": "https://example.com/doc.pdf",
      "filename": "report.pdf",
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
test "WhatsAppPlugin::handle_request send_location" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_location",
    params: Some({
      "to": "+1234567890",
      "latitude": 37.7749,
      "longitude": -122.4194,
      "name": "SF",
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
test "WhatsAppPlugin::handle_request send_buttons" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_buttons",
    params: Some({
      "to": "+1234567890",
      "body": "Choose an option",
      "buttons": [{ "id": "btn1", "title": "Option 1" }],
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
test "WhatsAppPlugin::handle_request send_template" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send_template",
    params: Some({
      "to": "+1234567890",
      "template_name": "hello_world",
      "language": "en_US",
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
test "WhatsAppPlugin::handle_request webhook" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "webhook",
    params: Some({ "hub.mode": "subscribe", "hub.challenge": "challenge123" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "challenge": String(c), .. }) => inspect(c, content="challenge123")
    _ => fail("Expected challenge result")
  }
}

///|
test "WhatsAppPlugin::handle_request receive" {
  let config : WhatsAppPluginConfig = {
    name: "test",
    phone_number_id: "123456",
    business_account_id: "789",
    api_version: "v18.0",
    verify_token: "token",
  }
  let plugin = WhatsAppPlugin::new(config)
  // First add a message via webhook
  let payload : Json = {
    "entry": [
      {
        "changes": [
          {
            "value": {
              "messages": [
                {
                  "id": "msg123",
                  "from": "+1234567890",
                  "timestamp": "1234567890",
                  "type": "text",
                  "text": { "body": "Hello" },
                },
              ],
            },
          },
        ],
      },
    ],
  }
  let _ = plugin.handle_webhook(payload)
  // Now receive
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "receive",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "text": String(t), "from": String(f), .. }) => {
      inspect(t, content="Hello")
      inspect(f, content="+1234567890")
    }
    _ => fail("Expected message result")
  }
}

///|
test "WhatsAppPlugin::handle_request receive empty" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
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
test "WhatsAppPlugin::handle_request status" {
  let config : WhatsAppPluginConfig = {
    name: "test",
    phone_number_id: "123456",
    business_account_id: "789",
    api_version: "v18.0",
    verify_token: "token",
  }
  let plugin = WhatsAppPlugin::new(config)
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
    Some({ "connected": True, "phone_number_id": String(p), .. }) =>
      inspect(p, content="123456")
    _ => fail("Expected connected status")
  }
}

///|
test "WhatsAppPlugin::handle_request connect" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
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
test "WhatsAppPlugin::handle_request disconnect" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
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
test "WhatsAppPlugin::handle_request method not found" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
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
test "WhatsAppPlugin::handle_webhook image message" {
  let config : WhatsAppPluginConfig = {
    name: "test",
    phone_number_id: "123456",
    business_account_id: "789",
    api_version: "v18.0",
    verify_token: "token",
  }
  let plugin = WhatsAppPlugin::new(config)
  let payload : Json = {
    "entry": [
      {
        "changes": [
          {
            "value": {
              "messages": [
                {
                  "id": "msg123",
                  "from": "+1234567890",
                  "timestamp": "1234567890",
                  "type": "image",
                  "image": {
                    "url": "https://example.com/image.jpg",
                    "caption": "Nice pic",
                  },
                },
              ],
            },
          },
        ],
      },
    ],
  }
  let _ = plugin.handle_webhook(payload)
  match plugin.receive() {
    Some(msg) => {
      match msg.message_type {
        Image => ()
        _ => fail("Expected image message type")
      }
      match msg.caption {
        Some(c) => inspect(c, content="Nice pic")
        None => fail("Expected caption")
      }
    }
    None => fail("Expected message")
  }
}
