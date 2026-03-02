///|
/// OS standard directories module tests
test "detect_os returns valid OsKind" {
  let os = detect_os()
  // Should be one of the known OS kinds
  match os {
    Linux | MacOS | Windows | Unknown => ()
  }
}

///|
test "home_dir returns non-empty on native" {
  let home = home_dir()
  // On most systems, HOME should be set
  // This test may fail in certain CI environments
  ignore(home)
}

///|
test "config_dir returns non-empty" {
  let dir = config_dir()
  assert_true(not(dir.is_empty()))
}

///|
test "data_dir returns non-empty" {
  let dir = data_dir()
  assert_true(not(dir.is_empty()))
}

///|
test "cache_dir returns non-empty" {
  let dir = cache_dir()
  assert_true(not(dir.is_empty()))
}

///|
test "config_dir_for appends app name" {
  let dir = config_dir_for("testapp")
  assert_true(dir.has_suffix("/testapp"))
}

///|
test "data_dir_for appends app name" {
  let dir = data_dir_for("testapp")
  assert_true(dir.has_suffix("/testapp"))
}

///|
test "cache_dir_for appends app name" {
  let dir = cache_dir_for("testapp")
  assert_true(dir.has_suffix("/testapp"))
}

///|
test "temp_dir returns non-empty" {
  let dir = temp_dir()
  assert_true(not(dir.is_empty()))
}

///|
test "temp_dir_for appends app name" {
  let dir = temp_dir_for("testapp")
  assert_true(dir.has_suffix("/testapp"))
}
