///|
/// Tests for constant_time_compare

test "constant_time_compare equal strings" {
  assert_true(constant_time_compare("hello", "hello"))
}

test "constant_time_compare different strings same length" {
  assert_false(constant_time_compare("hello", "world"))
}

test "constant_time_compare different lengths" {
  assert_false(constant_time_compare("short", "longer string"))
}

test "constant_time_compare empty strings" {
  assert_true(constant_time_compare("", ""))
}

test "constant_time_compare one empty" {
  assert_false(constant_time_compare("", "notempty"))
  assert_false(constant_time_compare("notempty", ""))
}

test "constant_time_compare tokens" {
  let token = "abc123-secret-token-xyz"
  assert_true(constant_time_compare(token, token))
  assert_false(constant_time_compare(token, "abc123-secret-token-xyZ"))
}
