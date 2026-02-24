///|
fn write_text_file(path : String, content : String) -> Unit {
  let result = @native.c_write_text_file(
    @native.string_to_cstring(path),
    @native.string_to_cstring(content),
  )
  if result != 0 {
    abort("failed to write test config")
  }
}

///|
fn remove_file(path : String) -> Unit {
  ignore(@native.c_remove_file(@native.string_to_cstring(path)))
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
test "bootstrap_runtime_channels_from_config registers multiple channels" {
  let path = "runtime_channels_native_test.json"
  let path2 = "runtime_channels_native_test_reload.json"
  let cleanup_path = "runtime_channels_native_cleanup.json"
  let config = "{\n" +
    "  \"channels\": [\n" +
    "    {\n" +
    "      \"name\": \"rt-ws-primary\",\n" +
    "      \"enabled\": true,\n" +
    "      \"token\": \"t1\",\n" +
    "      \"webhook_url\": \"wss://example.invalid/ws1\",\n" +
    "      \"options\": { \"type\": \"websocket\", \"receive_timeout_ms\": 25 }\n" +
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
  write_text_file(path2, config2)
  defer remove_file(path)
  defer remove_file(path2)
  write_cleanup_config(cleanup_path)
  defer remove_file(cleanup_path)
  defer bootstrap_runtime_channels_from_config(cleanup_path)

  bootstrap_runtime_channels_from_config(path)
  let names = registered_channel_names_for_test()
  assert_true(contains_name(names, "rt-ws-primary"))
  assert_true(contains_name(names, "rt-ws-secondary"))
  assert_true(contains_name(names, "rt-http-primary"))
  assert_eq(runtime_channel_holding_count_for_test(), 3)

  bootstrap_runtime_channels_from_config(path2)
  let names2 = registered_channel_names_for_test()
  assert_true(contains_name(names2, "rt-http-only"))
  assert_true(!contains_name(names2, "rt-ws-primary"))
  assert_true(!contains_name(names2, "rt-ws-secondary"))
  assert_true(!contains_name(names2, "rt-http-primary"))
  assert_eq(runtime_channel_holding_count_for_test(), 1)
}
