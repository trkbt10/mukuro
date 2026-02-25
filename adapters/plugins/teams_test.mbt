///|
test "AdaptiveCard to_json" {
  let card : AdaptiveCard = {
    body: [{ element_type: "TextBlock", text: "Hello", size: "Large", weight: "Bolder" }],
    actions: [],
  }
  let json = card.to_json()
  match json {
    { "type": String(t), "version": String(v), .. } => {
      inspect(t, content="AdaptiveCard")
      inspect(v, content="1.4")
    }
    _ => fail("Expected AdaptiveCard")
  }
}

///|
test "receive empty returns None" {
  let config = TeamsPluginConfig::default(name="test")
  let plugin = TeamsPlugin::new(config)
  inspect(plugin.receive() is None, content="true")
}
