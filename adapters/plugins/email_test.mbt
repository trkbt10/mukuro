///|
test "compose creates draft" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let to : Array[EmailAddress] = [{ email: "user@example.com", name: "" }]
  let draft = plugin.compose(to, "Subject", body_text="Body")
  inspect(draft.subject, content="Subject")
  inspect(draft.id.has_prefix("msg_"), content="true")
}

///|
test "compose multiple drafts" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let to : Array[EmailAddress] = [{ email: "a@b.com", name: "" }]
  let d1 = plugin.compose(to, "Draft1", body_text="body1")
  let d2 = plugin.compose(to, "Draft2", body_text="body2")
  // Verify unique IDs
  inspect(d1.id != d2.id, content="true")
}

///|
test "delete draft" {
  let config = EmailPluginConfig::default(name="test")
  let plugin = EmailPlugin::new(config)
  let to : Array[EmailAddress] = [{ email: "a@b.com", name: "" }]
  let draft = plugin.compose(to, "ToDelete", body_text="body")
  inspect(plugin.delete(draft.id), content="true")
  // Verify draft is removed
  inspect(plugin.get_message(draft.id) is None, content="true")
}
