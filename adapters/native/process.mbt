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
fn build_command(
  command : String,
  args : Array[String],
  options : @interfaces.ProcessOptions,
) -> String {
  let mut cmd = command
  for arg in args {
    let escaped = arg.split("'").collect().join("'\\''")
    cmd = cmd + " '" + escaped + "'"
  }
  match options.cwd {
    Some(cwd) => cmd = "cd '\{cwd}' && \{cmd}"
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
  let cmd = build_command(command, args, options)
  match c_popen(string_to_cstring(cmd), string_to_cstring("r")) {
    Some(pipe) => {
      let buffer = Bytes::new(65536)
      let bytes_read = c_fread(buffer, 1, 65536, pipe)
      let exit_code = c_pclose(pipe)
      let stdout = if bytes_read > 0 {
        Bytes::from_iter(buffer.sub(end=bytes_read).iter())
      } else {
        Bytes::new(0)
      }
      let actual_exit_code = (exit_code.reinterpret_as_uint() >> 8)
        .land(0xFFU)
        .reinterpret_as_int()
      { exit_code: actual_exit_code, stdout, stderr: Bytes::new(0) }
    }
    None => raise ProcessError::ExecutionFailed("Failed to execute: \{command}")
  }
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
  // Call implementation directly to get correct error type
  let cmd = build_command(
    "sh",
    ["-c", command],
    @interfaces.ProcessOptions::default(),
  )
  match c_popen(string_to_cstring(cmd), string_to_cstring("r")) {
    Some(pipe) => {
      let buffer = Bytes::new(65536)
      let bytes_read = c_fread(buffer, 1, 65536, pipe)
      let exit_code = c_pclose(pipe)
      let stdout = if bytes_read > 0 {
        Bytes::from_iter(buffer.sub(end=bytes_read).iter())
      } else {
        Bytes::new(0)
      }
      let actual_exit_code = (exit_code.reinterpret_as_uint() >> 8)
        .land(0xFFU)
        .reinterpret_as_int()
      { exit_code: actual_exit_code, stdout, stderr: Bytes::new(0) }
    }
    None => raise ProcessError::ExecutionFailed("Failed to execute: sh")
  }
}

///|
pub fn NativeProcessExecutor::command_exists(
  self : NativeProcessExecutor,
  command : String,
) -> Bool {
  try {
    let result = self.shell("command -v '\{command}'")
    result.exit_code == 0
  } catch {
    _ => false
  }
}
