///|
/// Stdio client security tests - command injection prevention

test "validate_env_key accepts valid key" {
  let result : Result[Unit, _] = try? validate_env_key("MY_VAR")
  assert_true(result is Ok(_))
}

test "validate_env_key accepts underscore prefix" {
  let result : Result[Unit, _] = try? validate_env_key("_VAR")
  assert_true(result is Ok(_))
}

test "validate_env_key accepts alphanumeric" {
  let result : Result[Unit, _] = try? validate_env_key("VAR123")
  assert_true(result is Ok(_))
}

test "validate_env_key rejects empty" {
  let result : Result[Unit, _] = try? validate_env_key("")
  assert_true(result is Err(_))
}

test "validate_env_key rejects semicolon" {
  let result : Result[Unit, _] = try? validate_env_key("VAR;evil")
  assert_true(result is Err(_))
}

test "validate_env_key rejects equals" {
  let result : Result[Unit, _] = try? validate_env_key("VAR=evil")
  assert_true(result is Err(_))
}

test "validate_env_key rejects space" {
  let result : Result[Unit, _] = try? validate_env_key("VAR evil")
  assert_true(result is Err(_))
}

test "validate_env_key rejects dollar" {
  let result : Result[Unit, _] = try? validate_env_key("$VAR")
  assert_true(result is Err(_))
}

test "validate_env_key rejects starting with digit" {
  let result : Result[Unit, _] = try? validate_env_key("9VAR")
  assert_true(result is Err(_))
}

test "escape_shell_single_quote handles normal string" {
  let result = escape_shell_single_quote("hello")
  assert_eq(result, "hello")
}

test "escape_shell_single_quote escapes single quotes" {
  let result = escape_shell_single_quote("it's")
  assert_eq(result, "it'\\''s")
}

test "escape_shell_single_quote handles multiple quotes" {
  let result = escape_shell_single_quote("a'b'c")
  assert_eq(result, "a'\\''b'\\''c")
}
