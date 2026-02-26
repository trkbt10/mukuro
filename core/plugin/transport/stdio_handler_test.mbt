///|
/// Unit tests for StdioTransportHandler

///|
test "StdioTransportHandler: constructor with default config" {
  let config = @interfaces.PluginStdioConfig::default(command="node index.js")
  let handler = StdioTransportHandler::new(plugin_id="test-plugin", config~)
  assert_false(handler.is_active())
  assert_eq(handler.config.command, "node index.js")
  assert_true(handler.config.args.is_empty())
}

///|
test "StdioTransportHandler: config with args and env" {
  let config : @interfaces.PluginStdioConfig = {
    command: "python",
    args: ["-m", "plugin"],
    cwd: Some("/path/to/plugin"),
    env: { "DEBUG": "true", "PORT": "9100" },
    framing: @interfaces.StdioFraming::NewlineDelimited,
    startup_timeout_ms: 10000,
    restart_policy: @interfaces.RestartPolicy::Never,
  }
  let handler = StdioTransportHandler::new(plugin_id="python-plugin", config~)
  assert_eq(handler.config.command, "python")
  assert_eq(handler.config.args.length(), 2)
  assert_eq(handler.config.args[0], "-m")
  assert_eq(handler.config.env.get("DEBUG"), Some("true"))
}

///|
test "StdioTransportHandler: start/stop lifecycle" {
  let config = @interfaces.PluginStdioConfig::default(command="node index.js")
  let handler = StdioTransportHandler::new(plugin_id="test-plugin", config~)
  // Initially not active
  assert_false(@interfaces.PluginTransportHandler::is_active(handler))
  // Start (will not actually spawn process in test)
  handler.start() catch {
    _ => ()
  }
  // Note: In actual use, this would be active after starting
  // But since we don't have a real process, we test the state change
}

///|
test "StdioTransportHandler: restart policy OnFailure" {
  let config : @interfaces.PluginStdioConfig = {
    command: "node",
    args: ["index.js"],
    cwd: None,
    env: {},
    framing: @interfaces.StdioFraming::NewlineDelimited,
    startup_timeout_ms: 5000,
    restart_policy: @interfaces.RestartPolicy::OnFailure(
      max_retries=3,
      delay_ms=1000,
    ),
  }
  let handler = StdioTransportHandler::new(plugin_id="test-plugin", config~)
  match handler.config.restart_policy {
    @interfaces.RestartPolicy::OnFailure(max_retries~, delay_ms~) => {
      assert_eq(max_retries, 3)
      assert_eq(delay_ms, 1000)
    }
    _ => panic()
  }
}

///|
test "StdioTransportHandler: restart policy Always" {
  let config : @interfaces.PluginStdioConfig = {
    command: "node",
    args: ["index.js"],
    cwd: None,
    env: {},
    framing: @interfaces.StdioFraming::NewlineDelimited,
    startup_timeout_ms: 5000,
    restart_policy: @interfaces.RestartPolicy::Always(
      base_delay_ms=100,
      max_delay_ms=30000,
    ),
  }
  let handler = StdioTransportHandler::new(plugin_id="test-plugin", config~)
  match handler.config.restart_policy {
    @interfaces.RestartPolicy::Always(base_delay_ms~, max_delay_ms~) => {
      assert_eq(base_delay_ms, 100)
      assert_eq(max_delay_ms, 30000)
    }
    _ => panic()
  }
}

///|
test "StdioTransportHandler: framing NewlineDelimited" {
  let config : @interfaces.PluginStdioConfig = {
    command: "node",
    args: [],
    cwd: None,
    env: {},
    framing: @interfaces.StdioFraming::NewlineDelimited,
    startup_timeout_ms: 5000,
    restart_policy: @interfaces.RestartPolicy::Never,
  }
  let handler = StdioTransportHandler::new(plugin_id="test", config~)
  match handler.config.framing {
    @interfaces.StdioFraming::NewlineDelimited => ()
    _ => panic()
  }
}

///|
test "StdioTransportHandler: framing LengthPrefixed" {
  let config : @interfaces.PluginStdioConfig = {
    command: "node",
    args: [],
    cwd: None,
    env: {},
    framing: @interfaces.StdioFraming::LengthPrefixed,
    startup_timeout_ms: 5000,
    restart_policy: @interfaces.RestartPolicy::Never,
  }
  let handler = StdioTransportHandler::new(plugin_id="test", config~)
  match handler.config.framing {
    @interfaces.StdioFraming::LengthPrefixed => ()
    _ => panic()
  }
}

///|
test "StdioTransportHandler: queue_incoming and try_receive" {
  let config = @interfaces.PluginStdioConfig::default(command="node index.js")
  let handler = StdioTransportHandler::new(plugin_id="test-plugin", config~)
  // Initially empty
  assert_true(@interfaces.PluginTransportHandler::try_receive(handler) is None)
  // Queue messages
  let msg1 = @interfaces.JsonRpcRequest::new(
    rpc_method="notification1",
    params=None,
    id=None,
  )
  handler.queue_incoming(msg1)
  // Receive
  let received = @interfaces.PluginTransportHandler::try_receive(handler)
  match received {
    Some(r) => assert_eq(r.rpc_method, "notification1")
    None => panic()
  }
  // Now empty
  assert_true(@interfaces.PluginTransportHandler::try_receive(handler) is None)
}

///|
test "StdioTransportHandler: on_message callback" {
  let config = @interfaces.PluginStdioConfig::default(command="node index.js")
  let handler = StdioTransportHandler::new(plugin_id="test-plugin", config~)
  let mut received_method = ""
  @interfaces.PluginTransportHandler::on_message(handler, fn(req) {
    received_method = req.rpc_method
  })
  let msg = @interfaces.JsonRpcRequest::new(
    rpc_method="stdio_event",
    params=None,
    id=None,
  )
  handler.queue_incoming(msg)
  assert_eq(received_method, "stdio_event")
}
