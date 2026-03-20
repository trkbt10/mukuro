///|
test "AllowlistManager allows when no config" {
  let mgr = AllowlistManager::new()
  inspect(mgr.is_allowed("telegram", "user1", "chat1"), content="true")
}

///|
test "AllowlistManager allows listed sender" {
  let mgr = AllowlistManager::new()
  mgr.add({
    enabled: true,
    channel: "telegram",
    senders: ["user1", "user2"],
    chat_ids: None,
  })
  inspect(mgr.is_allowed("telegram", "user1", "chat1"), content="true")
  inspect(mgr.is_allowed("telegram", "user2", "chat1"), content="true")
}

///|
test "AllowlistManager rejects unlisted sender" {
  let mgr = AllowlistManager::new()
  mgr.add({
    enabled: true,
    channel: "telegram",
    senders: ["user1"],
    chat_ids: None,
  })
  inspect(mgr.is_allowed("telegram", "user3", "chat1"), content="false")
}

///|
test "AllowlistManager allows when disabled" {
  let mgr = AllowlistManager::new()
  mgr.add({
    enabled: false,
    channel: "telegram",
    senders: ["user1"],
    chat_ids: None,
  })
  inspect(mgr.is_allowed("telegram", "user3", "chat1"), content="true")
}

///|
test "AllowlistManager filters by chat_id" {
  let mgr = AllowlistManager::new()
  mgr.add({
    enabled: true,
    channel: "discord",
    senders: ["user1"],
    chat_ids: Some(["chat_allowed"]),
  })
  inspect(mgr.is_allowed("discord", "user1", "chat_allowed"), content="true")
  inspect(mgr.is_allowed("discord", "user1", "chat_denied"), content="false")
}

///|
test "AllowlistManager different channel unaffected" {
  let mgr = AllowlistManager::new()
  mgr.add({
    enabled: true,
    channel: "telegram",
    senders: ["user1"],
    chat_ids: None,
  })
  // discord has no allowlist, so anyone is allowed
  inspect(mgr.is_allowed("discord", "anyone", "chat1"), content="true")
}

///|
test "AllowlistConfig from_json parses correctly" {
  let json : Json = {
    "channel": "telegram",
    "enabled": true,
    "senders": ["user1", "user2"],
    "chat_ids": ["chat1"],
  }
  match AllowlistConfig::from_json(json) {
    Some(config) => {
      inspect(config.channel, content="telegram")
      inspect(config.enabled, content="true")
      inspect(config.senders.length(), content="2")
    }
    None => fail("Expected Some")
  }
}

///|
test "load_allowlists_from_json loads array" {
  let json : Json = {
    "allowlists": [
      { "channel": "telegram", "senders": ["u1"] },
      { "channel": "discord", "enabled": false, "senders": [] },
    ],
  }
  let mgr = load_allowlists_from_json(json)
  inspect(mgr.configs.length(), content="2")
}
