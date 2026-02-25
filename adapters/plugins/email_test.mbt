///|
/// Email Plugin Tests

///|
test "EmailPlugin::new creates empty plugin" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  inspect(plugin.messages.length(), content="0")
  inspect(plugin.drafts.length(), content="0")
}

///|
test "EmailPluginConfig::default" {
  let config = EmailPluginConfig::default(name="my-email")
  inspect(config.name, content="my-email")
  inspect(config.provider, content="gmail")
  inspect(config.default_mailbox, content="INBOX")
  inspect(config.max_results, content="50")
}

///|
test "EmailAddress::format with name" {
  let addr : EmailAddress = { name: "John Doe", email: "john@example.com" }
  inspect(addr.format(), content="John Doe <john@example.com>")
}

///|
test "EmailAddress::format without name" {
  let addr : EmailAddress = { name: "", email: "john@example.com" }
  inspect(addr.format(), content="john@example.com")
}

///|
test "EmailPlugin::compose creates draft" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let msg = plugin.compose(
    [{ name: "Alice", email: "alice@example.com" }],
    "Hello",
    body_text="This is the body",
  )
  inspect(msg.subject, content="Hello")
  inspect(msg.labels.length(), content="1")
  inspect(plugin.drafts.length(), content="1")
}

///|
test "EmailPlugin::get_message from drafts" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let msg = plugin.compose(
    [{ name: "", email: "test@test.com" }],
    "Test Subject",
  )
  match plugin.get_message(msg.id) {
    Some(m) => inspect(m.subject, content="Test Subject")
    None => fail("Expected to find message")
  }
}

///|
test "EmailPlugin::get_message not found" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  inspect(plugin.get_message("nonexistent") is None, content="true")
}

///|
test "EmailSearchFilter::new creates empty filter" {
  let filter = EmailSearchFilter::new()
  inspect(filter.query is None, content="true")
  inspect(filter.from is None, content="true")
  inspect(filter.is_unread is None, content="true")
}

///|
test "EmailPlugin::handle_request compose" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "compose",
    params: Some({
      "to": [{ "email": "alice@example.com", "name": "Alice" }],
      "subject": "Test Subject",
      "body_text": "Test body",
    }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "subject": String(s), "id": String(_), .. }) =>
      inspect(s, content="Test Subject")
    _ => fail("Expected message result")
  }
}

///|
test "EmailPlugin::handle_request send" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let msg = plugin.compose([{ name: "", email: "test@test.com" }], "Test")
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "send",
    params: Some({ "id": msg.id }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "sent": True, .. }) => ()
    _ => fail("Expected sent: true")
  }
  // Should be moved from drafts to messages
  inspect(plugin.drafts.length(), content="0")
  inspect(plugin.messages.length(), content="1")
}

///|
test "EmailPlugin::handle_request get" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let msg = plugin.compose([{ name: "", email: "test@test.com" }], "Find Me")
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "get",
    params: Some({ "id": msg.id }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "subject": String(s), .. }) => inspect(s, content="Find Me")
    _ => fail("Expected message result")
  }
}

///|
test "EmailPlugin::handle_request search empty" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "search",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "messages": Array(arr), .. }) => inspect(arr.length(), content="0")
    _ => fail("Expected messages array")
  }
}

///|
test "EmailPlugin::handle_request delete draft" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let msg = plugin.compose([{ name: "", email: "test@test.com" }], "Delete Me")
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "delete",
    params: Some({ "id": msg.id }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "deleted": True, .. }) => ()
    _ => fail("Expected deleted: true")
  }
  inspect(plugin.drafts.length(), content="0")
}

///|
test "EmailPlugin::handle_request method not found" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
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
test "EmailPlugin::compose with cc and bcc" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let msg = plugin.compose(
    [{ name: "Alice", email: "alice@example.com" }],
    "With CC",
    cc=[{ name: "Bob", email: "bob@example.com" }],
    bcc=[{ name: "Charlie", email: "charlie@example.com" }],
  )
  inspect(msg.cc.length(), content="1")
  inspect(msg.bcc.length(), content="1")
}

///|
test "EmailPlugin::compose creates snippet" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let msg = plugin.compose(
    [{ name: "", email: "test@test.com" }],
    "Subject",
    body_text="Short body",
  )
  inspect(msg.snippet, content="Short body")
}
