///|
test "action_to_params navigate" {
  let action = BrowserAction::Navigate("https://example.com")
  let params = BrowserPlugin::action_to_params(action)
  inspect(params != Json::null(), content="true")
}

///|
test "action_to_params click" {
  let action = BrowserAction::Click("#button")
  let params = BrowserPlugin::action_to_params(action)
  inspect(params != Json::null(), content="true")
}

///|
test "action_to_params type_text" {
  let action = BrowserAction::Type(selector="#input", text="hello")
  let params = BrowserPlugin::action_to_params(action)
  inspect(params != Json::null(), content="true")
}

///|
test "record_action stores history" {
  let config = BrowserPluginConfig::default(name="test")
  let plugin = BrowserPlugin::new(config)
  plugin.record_action(BrowserAction::Navigate("https://test.com"))
  plugin.record_action(BrowserAction::Click("#btn"))
  inspect(plugin.get_history().length(), content="2")
}
