///|
/// Calendar Plugin Tests

///|
test "CalendarPlugin::new creates empty plugin" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  inspect(plugin.events.length(), content="0")
}

///|
test "CalendarPluginConfig::default" {
  let config = CalendarPluginConfig::default(name="my-cal")
  inspect(config.name, content="my-cal")
  inspect(config.provider, content="google")
  inspect(config.default_calendar_id, content="primary")
  inspect(config.default_reminder_minutes, content="15")
}

///|
test "CalendarPlugin::create_event basic" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let event = plugin.create_event(
    "Meeting", "2025-01-01T10:00:00Z", "2025-01-01T11:00:00Z",
  )
  inspect(event.title, content="Meeting")
  inspect(event.calendar_id, content="primary")
  inspect(event.status, content="confirmed")
}

///|
test "CalendarPlugin::create_event with options" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let event = plugin.create_event(
    "All Day Event",
    "2025-01-01",
    "2025-01-02",
    description="A full day event",
    location="Office",
    all_day=true,
    attendees=["alice@example.com", "bob@example.com"],
    reminder_minutes=Some(30),
  )
  inspect(event.all_day, content="true")
  inspect(event.location, content="Office")
  inspect(event.reminder_minutes, content="30")
  inspect(event.attendees.length(), content="2")
}

///|
test "CalendarPlugin::get_event" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let event = plugin.create_event(
    "Test", "2025-01-01T10:00:00Z", "2025-01-01T11:00:00Z",
  )
  match plugin.get_event(event.id) {
    Some(e) => inspect(e.title, content="Test")
    None => fail("Expected to find event")
  }
}

///|
test "CalendarPlugin::get_event not found" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  inspect(plugin.get_event("nonexistent") is None, content="true")
}

///|
test "CalendarPlugin::update_event" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let event = plugin.create_event(
    "Original", "2025-01-01T10:00:00Z", "2025-01-01T11:00:00Z",
  )
  let updated = plugin.update_event(
    event.id,
    title=Some("Updated Title"),
    location=Some("New Location"),
  )
  inspect(updated, content="true")
  match plugin.get_event(event.id) {
    Some(e) => {
      inspect(e.title, content="Updated Title")
      inspect(e.location, content="New Location")
    }
    None => fail("Expected to find event")
  }
}

///|
test "CalendarPlugin::delete_event" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let event = plugin.create_event(
    "ToDelete", "2025-01-01T10:00:00Z", "2025-01-01T11:00:00Z",
  )
  inspect(plugin.delete_event(event.id), content="true")
  inspect(plugin.get_event(event.id) is None, content="true")
}

///|
test "CalendarPlugin::list_events" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let _ = plugin.create_event(
    "Event1", "2025-01-01T10:00:00Z", "2025-01-01T11:00:00Z",
  )
  let _ = plugin.create_event(
    "Event2", "2025-01-02T10:00:00Z", "2025-01-02T11:00:00Z",
  )
  let _ = plugin.create_event(
    "Event3", "2025-01-03T10:00:00Z", "2025-01-03T11:00:00Z",
  )
  let events = plugin.list_events()
  inspect(events.length(), content="3")
}

///|
test "CalendarPlugin::list_events with time filter" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let _ = plugin.create_event(
    "Early", "2025-01-01T10:00:00Z", "2025-01-01T11:00:00Z",
  )
  let _ = plugin.create_event(
    "Middle", "2025-01-05T10:00:00Z", "2025-01-05T11:00:00Z",
  )
  let _ = plugin.create_event(
    "Late", "2025-01-10T10:00:00Z", "2025-01-10T11:00:00Z",
  )
  // Use full ISO 8601 timestamps for string comparison to work correctly
  let events = plugin.list_events(
    start_time=Some("2025-01-03T00:00:00Z"),
    end_time=Some("2025-01-08T23:59:59Z"),
  )
  inspect(events.length(), content="1")
}

///|
test "CalendarPlugin::get_availability" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let _ = plugin.create_event(
    "Busy", "2025-01-01T10:00:00Z", "2025-01-01T11:00:00Z",
  )
  let slots = plugin.get_availability(
    "2025-01-01T09:00:00Z", "2025-01-01T12:00:00Z",
  )
  inspect(slots.length(), content="1")
  inspect(slots[0].busy, content="true")
}

///|
test "RecurrenceRule::to_rrule daily" {
  let rule : RecurrenceRule = {
    frequency: "daily",
    interval: 1,
    by_day: [],
    by_month_day: None,
    until: None,
    count: Some(10),
  }
  inspect(rule.to_rrule(), content="FREQ=DAILY;COUNT=10")
}

///|
test "RecurrenceRule::to_rrule weekly" {
  let rule : RecurrenceRule = {
    frequency: "weekly",
    interval: 2,
    by_day: ["MO", "WE", "FR"],
    by_month_day: None,
    until: Some("20251231"),
    count: None,
  }
  inspect(
    rule.to_rrule(),
    content="FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;UNTIL=20251231",
  )
}

///|
test "CalendarPlugin::handle_request create_event" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "create_event",
    params: Some({
      "title": "Test Event",
      "start_time": "2025-01-01T10:00:00Z",
      "end_time": "2025-01-01T11:00:00Z",
      "description": "Test description",
    }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "title": String(t), "id": String(_), .. }) =>
      inspect(t, content="Test Event")
    _ => fail("Expected event result")
  }
}

///|
test "CalendarPlugin::handle_request get_event" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let event = plugin.create_event(
    "Find Me", "2025-01-01T10:00:00Z", "2025-01-01T11:00:00Z",
  )
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "get_event",
    params: Some({ "id": event.id }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "title": String(t), .. }) => inspect(t, content="Find Me")
    _ => fail("Expected event result")
  }
}

///|
test "CalendarPlugin::handle_request list_events" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
  let _ = plugin.create_event(
    "E1", "2025-01-01T10:00:00Z", "2025-01-01T11:00:00Z",
  )
  let _ = plugin.create_event(
    "E2", "2025-01-02T10:00:00Z", "2025-01-02T11:00:00Z",
  )
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "list_events",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "events": Array(arr), .. }) => inspect(arr.length(), content="2")
    _ => fail("Expected events array")
  }
}

///|
test "CalendarPlugin::handle_request method not found" {
  let config = CalendarPluginConfig::default(name="test")
  let plugin = CalendarPlugin::new(config)
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
