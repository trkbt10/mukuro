///|
test "remember stores entry" {
  let config = MemoryPluginConfig::default(name="test")
  let plugin = MemoryPlugin::new(config)
  let id = plugin.remember("Important info", [1.0, 0.0])
  inspect(id.has_prefix("mem_"), content="true")
  inspect(plugin.count(), content="1")
}

///|
test "get retrieves entry" {
  let config = MemoryPluginConfig::default(name="test")
  let plugin = MemoryPlugin::new(config)
  let id = plugin.remember("Test content", [1.0, 0.0])
  match plugin.get(id) {
    Some(entry) => inspect(entry.content, content="Test content")
    None => fail("Expected entry")
  }
}

///|
test "forget removes entry" {
  let config = MemoryPluginConfig::default(name="test")
  let plugin = MemoryPlugin::new(config)
  let id = plugin.remember("To forget", [1.0, 0.0])
  inspect(plugin.forget(id), content="true")
  inspect(plugin.count(), content="0")
}

///|
test "search finds similar" {
  let config = MemoryPluginConfig::default(name="test")
  let plugin = MemoryPlugin::new(config)
  let _ = plugin.remember("Apple", [1.0, 0.0, 0.0])
  let _ = plugin.remember("Banana", [0.9, 0.1, 0.0])
  let _ = plugin.remember("Car", [0.0, 0.0, 1.0])
  let results = plugin.search([1.0, 0.0, 0.0], limit=Some(2))
  inspect(results.length(), content="2")
}
