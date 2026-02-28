///|
/// Process security tests - command injection prevention
test "validate_command_name rejects semicolon" {
  let result : Result[Unit, _] = try? @native.validate_command_name(
    "cmd; rm -rf /",
  )
  assert_true(result is Err(_))
}

///|
test "validate_command_name rejects pipe" {
  let result : Result[Unit, _] = try? @native.validate_command_name(
    "cmd | evil",
  )
  assert_true(result is Err(_))
}

///|
test "validate_command_name rejects ampersand" {
  let result : Result[Unit, _] = try? @native.validate_command_name(
    "cmd && evil",
  )
  assert_true(result is Err(_))
}

///|
test "validate_command_name rejects backtick" {
  let result : Result[Unit, _] = try? @native.validate_command_name(
    "cmd `evil`",
  )
  assert_true(result is Err(_))
}

///|
test "validate_command_name rejects dollar" {
  let result : Result[Unit, _] = try? @native.validate_command_name(
    "cmd$(evil)",
  )
  assert_true(result is Err(_))
}

///|
test "validate_command_name rejects newline" {
  let result : Result[Unit, _] = try? @native.validate_command_name("cmd\nevil")
  assert_true(result is Err(_))
}

///|
test "validate_command_name rejects path traversal" {
  let result : Result[Unit, _] = try? @native.validate_command_name(
    "../../../bin/sh",
  )
  assert_true(result is Err(_))
}

///|
test "validate_command_name rejects empty" {
  let result : Result[Unit, _] = try? @native.validate_command_name("")
  assert_true(result is Err(_))
}

///|
test "validate_command_name accepts valid command" {
  let result : Result[Unit, _] = try? @native.validate_command_name("ls")
  assert_true(result is Ok(_))
}

///|
test "validate_command_name accepts path command" {
  let result : Result[Unit, _] = try? @native.validate_command_name(
    "/usr/bin/ls",
  )
  assert_true(result is Ok(_))
}

///|
test "validate_command_name accepts command with dash" {
  let result : Result[Unit, _] = try? @native.validate_command_name("my-tool")
  assert_true(result is Ok(_))
}
