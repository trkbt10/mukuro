///|
test "create_event" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let event = plugin.create_event(
    "Meeting",
    "2024-01-15T10:00:00Z",
    "2024-01-15T11:00:00Z",
  )
  inspect(event.title, content="Meeting")
  inspect(event.id.has_prefix("evt_"), content="true")
}

///|
test "delete_event" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let event = plugin.create_event("ToDelete", "2024-01-01T00:00:00Z", "2024-01-01T01:00:00Z")
  inspect(plugin.delete_event(event.id), content="true")
  inspect(plugin.list_events().length(), content="0")
}

///|
test "list_events" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let _ = plugin.create_event("Event1", "2024-01-01T00:00:00Z", "2024-01-01T01:00:00Z")
  let _ = plugin.create_event("Event2", "2024-01-02T00:00:00Z", "2024-01-02T01:00:00Z")
  inspect(plugin.list_events().length(), content="2")
}
