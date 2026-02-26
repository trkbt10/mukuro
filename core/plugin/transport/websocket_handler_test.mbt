///|
/// Unit tests for WebSocketTransportHandler

///|
test "WebSocketTransportHandler: constructor with default config" {
  let config = @interfaces.PluginWebSocketConfig::default(
    url="ws://localhost:9000",
  )
  let handler = WebSocketTransportHandler::new(plugin_id="test-plugin", config~)
  assert_false(@interfaces.PluginTransportHandler::is_active(handler))
}

///|
test "WebSocketTransportHandler: config with headers and reconnect" {
  let config : @interfaces.PluginWebSocketConfig = {
    url: "wss://example.com/ws",
    headers: { "Authorization": "Bearer token", "X-Custom": "value" },
    reconnect: {
      enabled: true,
      max_attempts: 10,
      base_delay_ms: 100,
      max_delay_ms: 60000,
    },
    heartbeat_interval_ms: 30000,
  }
  let handler = WebSocketTransportHandler::new(
    plugin_id="secure-plugin",
    config~,
  )
  assert_eq(handler.config.url, "wss://example.com/ws")
  assert_eq(handler.config.headers.get("Authorization"), Some("Bearer token"))
  assert_true(handler.config.reconnect.enabled)
  assert_eq(handler.config.reconnect.max_attempts, 10)
  assert_eq(handler.config.heartbeat_interval_ms, 30000)
}

///|
test "WebSocketTransportHandler: reconnect disabled" {
  let config : @interfaces.PluginWebSocketConfig = {
    url: "ws://localhost:8080",
    headers: {},
    reconnect: {
      enabled: false,
      max_attempts: 0,
      base_delay_ms: 1000,
      max_delay_ms: 30000,
    },
    heartbeat_interval_ms: 0,
  }
  let handler = WebSocketTransportHandler::new(
    plugin_id="no-reconnect",
    config~,
  )
  assert_false(handler.config.reconnect.enabled)
  assert_eq(handler.config.reconnect.max_attempts, 0)
}

///|
test "WebSocketTransportHandler: initial state is not active" {
  let config = @interfaces.PluginWebSocketConfig::default(
    url="ws://localhost:9000",
  )
  let handler = WebSocketTransportHandler::new(plugin_id="test", config~)
  // Check initial state - not active
  assert_false(@interfaces.PluginTransportHandler::is_active(handler))
}

///|
test "WebSocketTransportHandler: queue_incoming and try_receive" {
  let config = @interfaces.PluginWebSocketConfig::default(
    url="ws://localhost:9000",
  )
  let handler = WebSocketTransportHandler::new(plugin_id="test-plugin", config~)
  // Initially empty
  assert_true(@interfaces.PluginTransportHandler::try_receive(handler) is None)
  // Queue messages
  let msg1 = @interfaces.JsonRpcRequest::new(
    rpc_method="ws_event1",
    params=None,
    id=None,
  )
  let msg2 = @interfaces.JsonRpcRequest::new(
    rpc_method="ws_event2",
    params=Some(Json::object({ "data": "test" })),
    id=Some(1),
  )
  handler.queue_incoming(msg1)
  handler.queue_incoming(msg2)
  // Receive in order
  let received1 = @interfaces.PluginTransportHandler::try_receive(handler)
  match received1 {
    Some(r) => assert_eq(r.rpc_method, "ws_event1")
    None => panic()
  }
  let received2 = @interfaces.PluginTransportHandler::try_receive(handler)
  match received2 {
    Some(r) => {
      assert_eq(r.rpc_method, "ws_event2")
      assert_eq(r.id, Some(1))
    }
    None => panic()
  }
  // Now empty
  assert_true(@interfaces.PluginTransportHandler::try_receive(handler) is None)
}

///|
test "WebSocketTransportHandler: on_message callback" {
  let config = @interfaces.PluginWebSocketConfig::default(
    url="ws://localhost:9000",
  )
  let handler = WebSocketTransportHandler::new(plugin_id="test-plugin", config~)
  let mut callback_count = 0
  let mut received_method = ""
  @interfaces.PluginTransportHandler::on_message(handler, fn(req) {
    callback_count = callback_count + 1
    received_method = req.rpc_method
  })
  // Queue multiple messages
  let msg1 = @interfaces.JsonRpcRequest::new(
    rpc_method="event1",
    params=None,
    id=None,
  )
  let msg2 = @interfaces.JsonRpcRequest::new(
    rpc_method="event2",
    params=None,
    id=None,
  )
  handler.queue_incoming(msg1)
  handler.queue_incoming(msg2)
  // Callback should have been called for each message
  assert_eq(callback_count, 2)
  assert_eq(received_method, "event2")
}

///|
test "WebSocketTransportHandler: get_reconnect_delay" {
  let config : @interfaces.PluginWebSocketConfig = {
    url: "ws://localhost:9000",
    headers: {},
    reconnect: {
      enabled: true,
      max_attempts: 5,
      base_delay_ms: 100,
      max_delay_ms: 3200,
    },
    heartbeat_interval_ms: 0,
  }
  let handler = WebSocketTransportHandler::new(plugin_id="test", config~)
  // The delay uses exponential backoff based on internal attempt count
  let delay = handler.get_reconnect_delay()
  // Initial delay should be base_delay_ms
  assert_true(delay >= 100)
  assert_true(delay <= 3200)
}

///|
test "WebSocketTransportHandler: should_reconnect enabled" {
  let config : @interfaces.PluginWebSocketConfig = {
    url: "ws://localhost:9000",
    headers: {},
    reconnect: {
      enabled: true,
      max_attempts: 3,
      base_delay_ms: 100,
      max_delay_ms: 1000,
    },
    heartbeat_interval_ms: 0,
  }
  let handler = WebSocketTransportHandler::new(plugin_id="test", config~)
  // Should reconnect when enabled and attempts < max
  assert_true(handler.should_reconnect())
}

///|
test "WebSocketTransportHandler: should_reconnect disabled" {
  let config : @interfaces.PluginWebSocketConfig = {
    url: "ws://localhost:9000",
    headers: {},
    reconnect: {
      enabled: false,
      max_attempts: 5,
      base_delay_ms: 100,
      max_delay_ms: 1000,
    },
    heartbeat_interval_ms: 0,
  }
  let handler = WebSocketTransportHandler::new(plugin_id="test", config~)
  // Should never reconnect when disabled
  assert_false(handler.should_reconnect())
}

///|
test "WebSocketTransportHandler: default config values" {
  let config = @interfaces.PluginWebSocketConfig::default(
    url="ws://localhost:9999",
  )
  // Check default values
  assert_eq(config.url, "ws://localhost:9999")
  assert_true(config.headers.is_empty())
  // Default reconnect settings
  assert_true(config.reconnect.enabled)
  assert_eq(config.reconnect.max_attempts, 10)
  assert_eq(config.reconnect.base_delay_ms, 1000)
  assert_eq(config.reconnect.max_delay_ms, 30000)
  assert_eq(config.heartbeat_interval_ms, 30000)
}
