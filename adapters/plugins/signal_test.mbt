///|
test "create_send_command" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+1234567890",
    socket_path: "/tmp/signal",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let cmd = plugin.create_send_command("+0987654321", "Hello Signal")
  match cmd {
    { "jsonrpc": String(v), "method": String(m), .. } => {
      inspect(v, content="2.0")
      inspect(m, content="send")
    }
    _ => fail("Expected JSON-RPC command")
  }
}

///|
test "create_reaction_command" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+123",
    socket_path: "/tmp/signal",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let cmd = plugin.create_reaction_command("+456", "👍", "+789", 12345L)
  match cmd {
    { "method": String(m), .. } => inspect(m, content="sendReaction")
    _ => fail("Expected reaction command")
  }
}

///|
test "receive empty returns None" {
  let config = SignalPluginConfig::default(name="test")
  let plugin = SignalPlugin::new(config)
  inspect(plugin.receive() is None, content="true")
}
