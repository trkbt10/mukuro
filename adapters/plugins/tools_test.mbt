///|
test "calculate addition" {
  let plugin = UtilityToolPlugin::new(name="test")
  let result = plugin.calculate("2 + 3")
  inspect(result.success, content="true")
  inspect(result.result, content="5")
}

///|
test "calculate precedence" {
  let plugin = UtilityToolPlugin::new(name="test")
  let result = plugin.calculate("2 + 3 * 4")
  inspect(result.success, content="true")
  inspect(result.result, content="14")
}

///|
test "calculate parentheses" {
  let plugin = UtilityToolPlugin::new(name="test")
  let result = plugin.calculate("(2 + 3) * 4")
  inspect(result.success, content="true")
  inspect(result.result, content="20")
}

///|
test "uuid_v4 format" {
  let plugin = UtilityToolPlugin::new(name="test")
  let uuid = plugin.uuid_v4()
  inspect(uuid.length(), content="36")
  inspect(uuid[14] == '4', content="true")
}

///|
test "base64_encode" {
  let plugin = UtilityToolPlugin::new(name="test")
  inspect(plugin.base64_encode("Hello"), content="SGVsbG8=")
}
