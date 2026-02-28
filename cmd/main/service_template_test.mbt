///|
/// Service Template security tests
test "escape_xml escapes ampersand" {
  assert_eq(escape_xml("a&b"), "a&amp;b")
}

///|
test "escape_xml escapes angle brackets" {
  assert_eq(escape_xml("<script>"), "&lt;script&gt;")
}

///|
test "escape_xml escapes quotes" {
  assert_eq(escape_xml("a\"b'c"), "a&quot;b&#39;c")
}

///|
test "escape_xml preserves normal text" {
  assert_eq(escape_xml("hello world"), "hello world")
}

///|
test "escape_xml handles empty string" {
  assert_eq(escape_xml(""), "")
}

///|
test "escape_systemd_arg escapes dollar" {
  assert_eq(escape_systemd_arg("$HOME"), "$$HOME")
}

///|
test "escape_systemd_arg escapes percent" {
  assert_eq(escape_systemd_arg("100%"), "100%%")
}

///|
test "escape_systemd_arg escapes backslash" {
  assert_eq(escape_systemd_arg("a\\b"), "a\\\\b")
}

///|
test "escape_systemd_arg escapes double quote" {
  assert_eq(escape_systemd_arg("a\"b"), "a\\\"b")
}

///|
test "escape_systemd_arg preserves normal text" {
  assert_eq(escape_systemd_arg("hello world"), "hello world")
}

///|
test "generate_launchd_plist escapes xml in name" {
  let config : ServiceConfig = {
    name: "com.test<evil>&",
    display_name: "Test",
    executable: "/usr/bin/test",
    args: [],
    working_dir: "/tmp",
    config_path: None,
    user_level: true,
    auto_start: false,
    stdout_log: None,
    stderr_log: None,
  }
  let plist = generate_launchd_plist(config)
  assert_true(plist.contains("com.test&lt;evil&gt;&amp;"))
  assert_false(plist.contains("com.test<evil>&"))
}

///|
test "generate_systemd_unit escapes special chars" {
  let config : ServiceConfig = {
    name: "test",
    display_name: "Test $service",
    executable: "/usr/bin/test",
    args: ["--flag"],
    working_dir: "/tmp",
    config_path: None,
    user_level: true,
    auto_start: true,
    stdout_log: None,
    stderr_log: None,
  }
  let unit = generate_systemd_unit(config)
  assert_true(unit.contains("Test $$service"))
  assert_false(unit.contains("Test $service"))
}
