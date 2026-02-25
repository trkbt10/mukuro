///|
/// SQLite Memory Plugin Tests

///|
test "SqliteMemoryPlugin::new creates empty plugin" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  inspect(plugin.is_connected(), content="false")
  inspect(plugin.count(), content="0")
}

///|
test "SqliteMemoryPlugin::connect and disconnect" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  inspect(plugin.is_connected(), content="true")
  plugin.disconnect()
  inspect(plugin.is_connected(), content="false")
}

///|
test "SqliteMemoryPlugin::remember and get" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let id = plugin.remember("Hello, world!")
  let entry = plugin.get(id)
  match entry {
    Some(e) => {
      inspect(e.content, content="Hello, world!")
      inspect(e.importance, content="0.5")
    }
    None => fail("Expected to find memory entry")
  }
}

///|
test "SqliteMemoryPlugin::remember with metadata" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let id = plugin.remember(
    "Test content",
    metadata=Some("{\"key\":\"value\"}"),
    source=Some("test-source"),
    importance=Some(0.8),
  )
  match plugin.get(id) {
    Some(e) => {
      inspect(e.metadata, content="Some(\"{\\\"key\\\":\\\"value\\\"}\")")
      inspect(e.source, content="Some(\"test-source\")")
      inspect(e.importance, content="0.8")
    }
    None => fail("Expected to find memory entry")
  }
}

///|
test "SqliteMemoryPlugin::forget" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let id = plugin.remember("Test memory")
  inspect(plugin.count(), content="1")
  let deleted = plugin.forget(id)
  inspect(deleted, content="true")
  inspect(plugin.count(), content="0")
  // Verify the entry no longer exists
  match plugin.get(id) {
    Some(_) => fail("Expected None after forget")
    None => ()
  }
}

///|
test "SqliteMemoryPlugin::forget nonexistent returns false" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let deleted = plugin.forget("nonexistent")
  inspect(deleted, content="false")
}

///|
test "SqliteMemoryPlugin::update_importance" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let id = plugin.remember("Test memory")
  let updated = plugin.update_importance(id, 0.9)
  inspect(updated, content="true")
  match plugin.get(id) {
    Some(e) => inspect(e.importance, content="0.9")
    None => fail("Expected to find memory entry")
  }
}

///|
test "SqliteMemoryPlugin::search_text" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let _ = plugin.remember("The quick brown fox")
  let _ = plugin.remember("A lazy dog sleeps")
  let _ = plugin.remember("Fox and hound")
  let results = plugin.search_text("fox")
  inspect(results.length(), content="2")
}

///|
test "SqliteMemoryPlugin::search with embedding" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  // Add memories with embeddings (simple 3D vectors for testing)
  let _ = plugin.remember("First", embedding=Some([1.0, 0.0, 0.0]))
  let _ = plugin.remember("Second", embedding=Some([0.0, 1.0, 0.0]))
  let _ = plugin.remember("Third", embedding=Some([0.0, 0.0, 1.0]))
  // Search for vector similar to first
  let query = [0.9, 0.1, 0.0]
  let results = plugin.search(query)
  inspect(results.length() > 0, content="true")
  // First result should be the "First" memory
  match results[0] {
    { entry, score } => {
      inspect(entry.content, content="First")
      // Score should be high (close to 1.0)
      inspect(score > 0.9, content="true")
    }
  }
}

///|
test "SqliteMemoryPlugin::get_recent" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  let mut time = 1000L
  plugin.set_timestamp_provider(fn() { time })
  plugin.connect()
  // Add memories with different timestamps
  let _ = plugin.remember("Old memory")
  time = 2000L
  let _ = plugin.remember("Middle memory")
  time = 3000L
  let _ = plugin.remember("Recent memory")
  let results = plugin.get_recent(limit=Some(2))
  inspect(results.length(), content="2")
  inspect(results[0].content, content="Recent memory")
  inspect(results[1].content, content="Middle memory")
}

///|
test "SqliteMemoryPlugin::compact" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  // Add memories with different importance
  let _ = plugin.remember("Low", importance=Some(0.1))
  let _ = plugin.remember("Medium", importance=Some(0.5))
  let _ = plugin.remember("High", importance=Some(0.9))
  inspect(plugin.count(), content="3")
  // Keep only 2 most important
  let removed = plugin.compact(2)
  inspect(removed, content="1")
  inspect(plugin.count(), content="2")
}

///|
test "SqliteMemoryPlugin::clear" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let _ = plugin.remember("Memory 1")
  let _ = plugin.remember("Memory 2")
  inspect(plugin.count(), content="2")
  plugin.clear()
  inspect(plugin.count(), content="0")
}

///|
test "SqliteMemoryPlugin::handle_request remember" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "remember",
    params: Some({ "content": "Test memory content" }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "id": String(id), .. }) =>
      inspect(id.has_prefix("mem_"), content="true")
    _ => fail("Expected id in result")
  }
}

///|
test "SqliteMemoryPlugin::handle_request get" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let id = plugin.remember("Test content")
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "get",
    params: Some({ "id": id }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "entry": Object(entry), .. }) =>
      match entry.get("content") {
        Some(String(content)) => inspect(content, content="Test content")
        _ => fail("Expected content in entry")
      }
    _ => fail("Expected entry in result")
  }
}

///|
test "SqliteMemoryPlugin::handle_request status" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
  plugin.connect()
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "status",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some(
      {
        "connected": True,
        "db_path": String(_),
        "embedding_dimension": Number(_),
        ..
      }
    ) => ()
    _ => fail("Expected connected, db_path, and embedding_dimension in status")
  }
}

///|
test "SqliteMemoryPlugin::handle_request method not found" {
  let config = SqliteMemoryConfig::default(
    name="test-memory",
    db_path=":memory:",
  )
  let plugin = SqliteMemoryPlugin::new(config)
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
