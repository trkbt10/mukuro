///|
test "set and get" {
  let config = StoragePluginConfig::default(name="test")
  let plugin = MemoryStoragePlugin::new(config)
  plugin.set("key1", { "value": 123 })
  match plugin.get("key1") {
    Some(v) =>
      match v {
        { "value": Number(n, ..), .. } => inspect(n, content="123")
        _ => fail("Expected object")
      }
    None => fail("Expected value")
  }
}

///|
test "delete removes key" {
  let config = StoragePluginConfig::default(name="test")
  let plugin = MemoryStoragePlugin::new(config)
  plugin.set("key1", "data")
  inspect(plugin.delete("key1"), content="true")
  inspect(plugin.exists("key1"), content="false")
}

///|
test "clear removes all" {
  let config = StoragePluginConfig::default(name="test")
  let plugin = MemoryStoragePlugin::new(config)
  plugin.set("a", "1")
  plugin.set("b", "2")
  plugin.clear()
  inspect(plugin.count(), content="0")
}
