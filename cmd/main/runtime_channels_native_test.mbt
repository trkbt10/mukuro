///|
fn write_text_file(path : String, content : String) -> Unit {
  let result = @native.c_write_text_file_bytes(
    @native.string_to_utf8_cstring(path),
    @native.string_to_utf8_cstring(content),
  )
  if result != 0 {
    abort("failed to write test config")
  }
}

///|
fn remove_file(path : String) -> Unit {
  ignore(@native.c_remove_file_bytes(@native.string_to_utf8_cstring(path)))
}

///|
fn write_cleanup_config(path : String) -> Unit {
  let config = "{\n  \"channels\": []\n}\n"
  write_text_file(path, config)
}

///|
fn contains_name(names : Array[String], target : String) -> Bool {
  for name in names {
    if name == target {
      return true
    }
  }
  false
}

///|
fn expect_websocket_config(name : String) -> @channels.WebSocketChannelConfig {
  match runtime_websocket_config_for_test(name) {
    Some(config) => config
    None => abort("missing websocket config")
  }
}

///|
test "bootstrap_runtime_channels_from_config registers multiple channels" {
  let path = "runtime_channels_native_test.json"
  let cleanup_path = "runtime_channels_native_cleanup.json"
  let config = "{\n" +
    "  \"channels\": [\n" +
    "    {\n" +
    "      \"name\": \"rt-ws-primary\",\n" +
    "      \"enabled\": true,\n" +
    "      \"token\": \"t1\",\n" +
    "      \"webhook_url\": \"wss://example.invalid/ws1\",\n" +
    "      \"options\": {\n" +
    "        \"type\": \"websocket\",\n" +
    "        \"receive_timeout_ms\": 25,\n" +
    "        \"reconnect_interval_ms\": 123,\n" +
    "        \"max_reconnect_attempts\": 7,\n" +
    "        \"heartbeat_interval_ms\": 4500\n" +
    "      }\n" +
    "    },\n" +
    "    {\n" +
    "      \"name\": \"rt-ws-secondary\",\n" +
    "      \"enabled\": true,\n" +
    "      \"options\": { \"type\": \"websocket\", \"url\": \"wss://example.invalid/ws2\" }\n" +
    "    },\n" +
    "    {\n" +
    "      \"name\": \"rt-http-primary\",\n" +
    "      \"enabled\": true,\n" +
    "      \"token\": \"t2\",\n" +
    "      \"webhook_url\": \"https://example.invalid/hook\"\n" +
    "    }\n" +
    "  ]\n" +
    "}\n"
  let config2 = "{\n" +
    "  \"channels\": [\n" +
    "    {\n" +
    "      \"name\": \"rt-http-only\",\n" +
    "      \"enabled\": true,\n" +
    "      \"webhook_url\": \"https://example.invalid/hook2\"\n" +
    "    }\n" +
    "  ]\n" +
    "}\n"
  write_text_file(path, config)
  defer remove_file(path)
  write_cleanup_config(cleanup_path)
  defer remove_file(cleanup_path)
  defer bootstrap_runtime_channels_from_config(cleanup_path)

  bootstrap_runtime_channels_from_config(path)
  let names = registered_channel_names_for_test()
  assert_true(contains_name(names, "rt-ws-primary"))
  assert_true(contains_name(names, "rt-ws-secondary"))
  assert_true(contains_name(names, "rt-http-primary"))
  assert_eq(runtime_channel_holding_count_for_test(), 3)
  let ws_primary = expect_websocket_config("rt-ws-primary")
  assert_eq(ws_primary.receive_timeout_ms, 25)
  assert_eq(ws_primary.base.reconnect_interval_ms, 123)
  assert_eq(ws_primary.base.max_reconnect_attempts, 7)
  assert_eq(ws_primary.heartbeat_interval_ms, 4500)

  write_text_file(path, config2)
  bootstrap_runtime_channels_from_config(path)
  let names2 = registered_channel_names_for_test()
  assert_true(contains_name(names2, "rt-http-only"))
  assert_true(!contains_name(names2, "rt-ws-primary"))
  assert_true(!contains_name(names2, "rt-ws-secondary"))
  assert_true(!contains_name(names2, "rt-http-primary"))
  assert_eq(runtime_channel_holding_count_for_test(), 1)
}
