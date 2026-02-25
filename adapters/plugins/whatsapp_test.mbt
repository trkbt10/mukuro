///|
test "create_text_message" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let msg = plugin.create_text_message("+1234567890", "Hello")
  match msg {
    { "type": String(t), .. } => inspect(t, content="text")
    _ => fail("Expected text message")
  }
}

///|
test "create_image_message" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  let msg = plugin.create_image_message("+123", "https://example.com/image.jpg")
  match msg {
    { "type": String(t), .. } => inspect(t, content="image")
    _ => fail("Expected image message")
  }
}

///|
test "receive empty returns None" {
  let config = WhatsAppPluginConfig::default(name="test")
  let plugin = WhatsAppPlugin::new(config)
  inspect(plugin.receive() is None, content="true")
}
