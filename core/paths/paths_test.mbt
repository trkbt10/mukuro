///|
/// Paths module tests
test "config_dir defaults to standard mode" {
  // Reset to default state
  set_path_mode(PathMode::Standard)
  let dir = config_dir()
  // On macOS/Linux, should not be ".mukuro" (unless home is empty)
  let home = @dirs.home_dir()
  if not(home.is_empty()) {
    assert_true(not(dir == ".mukuro"))
  }
}

///|
test "config_dir in local mode returns .mukuro" {
  set_path_mode(PathMode::Local)
  let dir = config_dir()
  assert_eq(dir, ".mukuro")
  // Reset
  set_path_mode(PathMode::Standard)
}

///|
test "config_dir in custom mode returns custom path" {
  set_path_mode(PathMode::Custom("/tmp/my-mukuro"))
  let dir = config_dir()
  assert_eq(dir, "/tmp/my-mukuro")
  // Reset
  set_path_mode(PathMode::Standard)
}

///|
test "config_file returns correct path" {
  set_path_mode(PathMode::Local)
  let path = config_file()
  assert_eq(path, ".mukuro/config.json")
  set_path_mode(PathMode::Standard)
}

///|
test "pid_file returns cache_dir based path" {
  set_path_mode(PathMode::Local)
  let path = pid_file()
  assert_eq(path, ".mukuro/gateway.pid")
  set_path_mode(PathMode::Standard)
}

///|
test "state_file returns data_dir based path" {
  set_path_mode(PathMode::Local)
  let path = state_file()
  assert_eq(path, ".mukuro/gateway-state.json")
  set_path_mode(PathMode::Standard)
}

///|
test "workspace_dir returns data_dir based path" {
  set_path_mode(PathMode::Local)
  let path = workspace_dir()
  assert_eq(path, ".mukuro/workspace")
  set_path_mode(PathMode::Standard)
}

///|
test "get_path_mode returns current mode" {
  set_path_mode(PathMode::Local)
  match get_path_mode() {
    Local => ()
    _ => fail("Expected Local mode")
  }
  set_path_mode(PathMode::Custom("/custom"))
  match get_path_mode() {
    Custom(p) => assert_eq(p, "/custom")
    _ => fail("Expected Custom mode")
  }
  set_path_mode(PathMode::Standard)
}
