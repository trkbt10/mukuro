///|
/// SQLite Storage Plugin Tests

///|
test "SqliteStoragePlugin::new creates empty plugin" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  inspect(plugin.is_connected(), content="false")
  inspect(plugin.count(), content="0")
}

///|
test "SqliteStoragePlugin::connect and disconnect" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  inspect(plugin.is_connected(), content="true")
  plugin.disconnect()
  inspect(plugin.is_connected(), content="false")
}

///|
test "SqliteStoragePlugin::set and get" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  plugin.set("key1", Json::string("value1"))
  let result = plugin.get("key1")
  inspect(result, content="Some(String(\"value1\"))")
}

///|
test "SqliteStoragePlugin::get nonexistent key returns None" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  let result = plugin.get("nonexistent")
  inspect(result, content="None")
}

///|
test "SqliteStoragePlugin::delete" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  plugin.set("key1", Json::string("value1"))
  let deleted = plugin.delete("key1")
  inspect(deleted, content="true")
  let result = plugin.get("key1")
  inspect(result, content="None")
}

///|
test "SqliteStoragePlugin::delete nonexistent returns false" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  let deleted = plugin.delete("nonexistent")
  inspect(deleted, content="false")
}

///|
test "SqliteStoragePlugin::exists" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  plugin.set("key1", Json::string("value1"))
  inspect(plugin.exists("key1"), content="true")
  inspect(plugin.exists("nonexistent"), content="false")
}

///|
test "SqliteStoragePlugin::keys" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  plugin.set("key1", Json::string("value1"))
  plugin.set("key2", Json::string("value2"))
  let keys = plugin.keys()
  inspect(keys.length(), content="2")
}

///|
test "SqliteStoragePlugin::clear" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  plugin.set("key1", Json::string("value1"))
  plugin.set("key2", Json::string("value2"))
  plugin.clear()
  inspect(plugin.count(), content="0")
}

///|
test "SqliteStoragePlugin::count" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  inspect(plugin.count(), content="0")
  plugin.set("key1", Json::string("value1"))
  inspect(plugin.count(), content="1")
  plugin.set("key2", Json::string("value2"))
  inspect(plugin.count(), content="2")
}

///|
test "SqliteStoragePlugin::TTL expiration" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  let mut current_time = 1000L
  plugin.set_timestamp_provider(fn() { current_time })
  plugin.connect()
  // Set with 100ms TTL
  plugin.set("key1", Json::string("value1"), ttl_ms=Some(100L))
  // Should exist before expiration
  inspect(plugin.exists("key1"), content="true")
  // Advance time past expiration
  current_time = 1200L
  // Should be expired now
  inspect(plugin.exists("key1"), content="false")
  inspect(plugin.get("key1"), content="None")
}

///|
test "SqliteStoragePlugin::key prefix" {
  let config : SqliteStorageConfig = {
    name: "test-storage",
    db_path: ":memory:",
    default_ttl_ms: 0L,
    key_prefix: "myprefix",
  }
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  plugin.set("key1", Json::string("value1"))
  // Should be able to get via unprefixed key
  inspect(plugin.get("key1"), content="Some(String(\"value1\"))")
  // Keys should show unprefixed
  let keys = plugin.keys()
  inspect(keys.contains("key1"), content="true")
}

///|
test "SqliteStoragePlugin::handle_request get" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  plugin.set("key1", Json::string("value1"))
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "get",
    params: Some({ "key": "key1" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "value": String(v), .. }) => inspect(v, content="value1")
    _ => fail("Expected value in result")
  }
}

///|
test "SqliteStoragePlugin::handle_request set" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "set",
    params: Some({ "key": "key1", "value": "hello" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "ok": True, .. }) => ()
    _ => fail("Expected ok result")
  }
  inspect(plugin.get("key1"), content="Some(String(\"hello\"))")
}

///|
test "SqliteStoragePlugin::handle_request status" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "status",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "connected": True, "db_path": String(_), .. }) => ()
    _ => fail("Expected connected and db_path in status")
  }
}

///|
test "SqliteStoragePlugin::handle_request method not found" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
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
test "SqliteStoragePlugin::JSON object storage" {
  let config = SqliteStorageConfig::default(
    name="test-storage",
    db_path=":memory:",
  )
  let plugin = SqliteStoragePlugin::new(config)
  plugin.connect()
  let obj : Json = { "name": "test", "count": 42, "active": true }
  plugin.set("obj_key", obj)
  match plugin.get("obj_key") {
    Some(Object(result)) =>
      match result.get("name") {
        Some(String(name)) => inspect(name, content="test")
        _ => fail("Expected name field")
      }
    _ => fail("Expected object result")
  }
}
