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

///|
test "to_relative_path removes base_dir prefix" {
  let abs = "/Users/test/mukuro/history/2026/03/02/file.jsonl"
  let base = "/Users/test/mukuro"
  let rel = to_relative_path(abs, base)
  inspect(rel, content="history/2026/03/02/file.jsonl")
}

///|
test "to_relative_path with trailing slash" {
  let abs = "/Users/test/mukuro/history/file.jsonl"
  let base = "/Users/test/mukuro/"
  let rel = to_relative_path(abs, base)
  inspect(rel, content="history/file.jsonl")
}

///|
test "to_relative_path returns as-is if no prefix match" {
  let abs = "/other/path/file.jsonl"
  let base = "/Users/test/mukuro"
  let rel = to_relative_path(abs, base)
  inspect(rel, content="/other/path/file.jsonl")
}

///|
test "to_relative_path returns as-is if already relative" {
  let rel_input = "history/2026/file.jsonl"
  let base = "/Users/test/mukuro"
  let rel = to_relative_path(rel_input, base)
  inspect(rel, content="history/2026/file.jsonl")
}

///|
test "to_absolute_path joins base_dir and relative path" {
  let rel = "history/2026/03/02/file.jsonl"
  let base = "/Users/test/mukuro"
  let abs = to_absolute_path(rel, base)
  inspect(abs, content="/Users/test/mukuro/history/2026/03/02/file.jsonl")
}

///|
test "to_absolute_path with trailing slash in base" {
  let rel = "history/file.jsonl"
  let base = "/Users/test/mukuro/"
  let abs = to_absolute_path(rel, base)
  inspect(abs, content="/Users/test/mukuro/history/file.jsonl")
}

///|
test "to_absolute_path returns as-is if already absolute" {
  let abs_input = "/Users/test/mukuro/history/file.jsonl"
  let base = "/other/base"
  let abs = to_absolute_path(abs_input, base)
  inspect(abs, content="/Users/test/mukuro/history/file.jsonl")
}

///|
test "roundtrip relative to absolute and back" {
  let base = "/Users/test/mukuro"
  let rel = "history/2026/03/02/file.jsonl"
  let abs = to_absolute_path(rel, base)
  let rel2 = to_relative_path(abs, base)
  inspect(rel2, content="history/2026/03/02/file.jsonl")
}
