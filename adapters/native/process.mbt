///|
/// Native Process 実装

///|
pub(all) suberror ProcessError {
  ExecutionFailed(String)
  Timeout
  SignalReceived(Int)
}

///|
pub struct NativeProcessExecutor {
  default_timeout_ms : Int64
}

///|
pub fn NativeProcessExecutor::new(
  default_timeout_ms~ : Int64,
) -> NativeProcessExecutor {
  { default_timeout_ms, }
}

///|
pub fn NativeProcessExecutor::default() -> NativeProcessExecutor {
  { default_timeout_ms: 30000L }
}

///|
/// Validate command name - reject shell metacharacters and path traversal
pub fn validate_command_name(command : String) -> Unit raise ProcessError {
  if command.length() == 0 {
    raise ProcessError::ExecutionFailed("Empty command name")
  }
  let chars = command.to_array()
  for c in chars {
    match c {
      ';'
      | '&'
      | '|'
      | '$'
      | '`'
      | '('
      | ')'
      | '{'
      | '}'
      | '<'
      | '>'
      | '\n'
      | '\r'
      | '\''
      | '"'
      | '\\'
      | '!'
      | '~'
      | '*'
      | '?'
      | '['
      | ']'
      | '#' =>
        raise ProcessError::ExecutionFailed(
          "Invalid character '\{c}' in command name: \{command}",
        )
      _ => ()
    }
  }
  // Reject path traversal
  if command.contains("..") {
    raise ProcessError::ExecutionFailed(
      "Path traversal not allowed in command name: \{command}",
    )
  }
}

///|
fn build_command(
  command : String,
  args : Array[String],
  options : @interfaces.ProcessOptions,
) -> String raise ProcessError {
  validate_command_name(command)
  let mut cmd = command
  for arg in args {
    let escaped = escape_shell_single_quote(arg)
    cmd = cmd + " '" + escaped + "'"
  }
  match options.cwd {
    Some(cwd) => {
      let escaped_cwd = escape_shell_single_quote(cwd)
      cmd = "cd '" + escaped_cwd + "' && " + cmd
    }
    None => ()
  }
  cmd
}

///|
pub impl @interfaces.ProcessExecutor for NativeProcessExecutor with exec(
  self,
  command~,
  args~,
  options~,
) {
  ignore(self)
  let cmd = build_command(command, args, options) catch {
    ProcessError::ExecutionFailed(msg) =>
      raise ProcessError::ExecutionFailed(msg)
    e => raise e
  }
  let handle = c_popen_handle(string_to_utf8_cstring(cmd), string_to_utf8_cstring("r"))
  if handle == 0L {
    raise ProcessError::ExecutionFailed("Failed to execute: \{command}")
  }
  let buffer = Bytes::new(65536)
  let bytes_read = c_fread_handle(buffer, 1, 65536, handle)
  let exit_code = c_pclose_handle(handle)
  let stdout = if bytes_read > 0 {
    @bytes.copy_slice(buffer[:bytes_read])
  } else {
    Bytes::new(0)
  }
  let actual_exit_code = (exit_code.reinterpret_as_uint() >> 8)
    .land(0xFFU)
    .reinterpret_as_int()
  { exit_code: actual_exit_code, stdout, stderr: Bytes::new(0) }
}

///|
pub impl @interfaces.ProcessExecutor for NativeProcessExecutor with exec_async(
  self,
  command~,
  args~,
  options~,
  on_complete~,
  on_error~,
) {
  try {
    let result = self.exec(command~, args~, options~)
    on_complete(result)
  } catch {
    ProcessError::ExecutionFailed(msg) => on_error(msg)
    _ => on_error("Unknown error")
  }
}

///|
pub fn NativeProcessExecutor::shell(
  self : NativeProcessExecutor,
  command : String,
) -> @interfaces.ProcessResult raise ProcessError {
  ignore(self)
  let cmd = build_command(
    "sh",
    ["-c", command],
    @interfaces.ProcessOptions::default(),
  ) catch {
    e => raise e
  }
  let handle = c_popen_handle(string_to_utf8_cstring(cmd), string_to_utf8_cstring("r"))
  if handle == 0L {
    raise ProcessError::ExecutionFailed("Failed to execute: sh")
  }
  let buffer = Bytes::new(65536)
  let bytes_read = c_fread_handle(buffer, 1, 65536, handle)
  let exit_code = c_pclose_handle(handle)
  let stdout = if bytes_read > 0 {
    @bytes.copy_slice(buffer[:bytes_read])
  } else {
    Bytes::new(0)
  }
  let actual_exit_code = (exit_code.reinterpret_as_uint() >> 8)
    .land(0xFFU)
    .reinterpret_as_int()
  { exit_code: actual_exit_code, stdout, stderr: Bytes::new(0) }
}

///|
pub fn NativeProcessExecutor::command_exists(
  self : NativeProcessExecutor,
  command : String,
) -> Bool {
  try {
    validate_command_name(command)
    let escaped = escape_shell_single_quote(command)
    let result = self.shell("command -v '" + escaped + "'")
    result.exit_code == 0
  } catch {
    _ => false
  }
}
