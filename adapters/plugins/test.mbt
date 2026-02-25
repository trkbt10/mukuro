///|
/// Plugin Tests - adapters/plugins scope only

// =============================================================================
// Storage Plugin
// =============================================================================

///|
test "MemoryStoragePlugin set and get" {
  let config = StoragePluginConfig::default(name="test")
  let plugin = MemoryStoragePlugin::new(config)
  plugin.set("key1", { "value": 123 })
  match plugin.get("key1") {
    Some(v) =>
      match v {
        { "value": Number(n, ..), .. } => inspect!(n, content="123")
        _ => fail!("Expected object")
      }
    None => fail!("Expected value")
  }
}

///|
test "MemoryStoragePlugin delete" {
  let config = StoragePluginConfig::default(name="test")
  let plugin = MemoryStoragePlugin::new(config)
  plugin.set("key1", "data")
  inspect!(plugin.delete("key1"), content="true")
  inspect!(plugin.exists("key1"), content="false")
}

// =============================================================================
// Scheduler Plugin
// =============================================================================

///|
test "SchedulerPlugin schedule_once" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  match plugin.schedule_once("test_task", "my_method", None, 1000L) {
    Some(id) => inspect!(id.has_prefix("task_"), content="true")
    None => fail!("Expected task ID")
  }
}

// =============================================================================
// Tools Plugin
// =============================================================================

///|
test "UtilityToolPlugin calculate" {
  let plugin = UtilityToolPlugin::new(name="test")
  let result = plugin.calculate("2 + 3")
  inspect!(result.success, content="true")
  inspect!(result.result, content="5")
}

///|
test "UtilityToolPlugin uuid_v4" {
  let plugin = UtilityToolPlugin::new(name="test")
  let uuid = plugin.uuid_v4()
  inspect!(uuid.length(), content="36")
  inspect!(uuid[14] == '4', content="true")
}

// =============================================================================
// Calendar Plugin
// =============================================================================

///|
test "CalendarPlugin create event" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let event = plugin.create_event(
    "Meeting",
    "2024-01-15T10:00:00Z",
    "2024-01-15T11:00:00Z",
  )
  inspect!(event.title, content="Meeting")
}

// =============================================================================
// Memory Plugin
// =============================================================================

///|
test "MemoryPlugin remember" {
  let config = MemoryPluginConfig::default(name="test")
  let plugin = MemoryPlugin::new(config)
  let id = plugin.remember("Important", [1.0, 0.0])
  inspect!(id.has_prefix("mem_"), content="true")
}

// =============================================================================
// Voice Plugin
// =============================================================================

///|
test "VoicePlugin synthesize" {
  let config = VoicePluginConfig::default(name="test")
  let plugin = VoicePlugin::new(config)
  let result = plugin.synthesize("Hello")
  inspect!(result.id.has_prefix("tts_"), content="true")
}

// =============================================================================
// Browser Plugin
// =============================================================================

///|
test "BrowserPlugin action_to_params" {
  let action = BrowserAction::Navigate("https://example.com")
  let params = BrowserPlugin::action_to_params(action)
  inspect!(params != Json::null(), content="true")
}

// =============================================================================
// Channel Plugins
// =============================================================================

///|
test "WhatsAppPlugin create text message" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let msg = plugin.create_text_message("+123", "Hi")
  match msg {
    { "type": String(t), .. } => inspect!(t, content="text")
    _ => fail!("Expected text message")
  }
}

///|
test "SignalPlugin send command" {
  let config : SignalPluginConfig = {
    name: "test",
    phone_number: "+123",
    socket_path: "/tmp/signal",
    trust_all: false,
  }
  let plugin = SignalPlugin::new(config)
  let cmd = plugin.create_send_command("+456", "Hello")
  match cmd {
    { "jsonrpc": String(v), .. } => inspect!(v, content="2.0")
    _ => fail!("Expected JSON-RPC")
  }
}
