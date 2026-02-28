///|
/// Hello World Plugin (Native) - Main entry point
/// Runs as a standalone process communicating via stdin/stdout JSON-RPC

// FFI declarations for stdin/stdout (native only)
#borrow(buffer)
extern "C" fn c_read_stdin_line(buffer : Bytes, buffer_len : Int) -> Int = "moonbit_read_stdin_line"

///|
#borrow(data)
extern "C" fn c_write_stdout(data : Bytes, len : Int) -> Int = "moonbit_write_stdout"

///|
/// Read a line from stdin (native backend only)
fn read_stdin_line() -> String? {
  let buffer = Bytes::new(65536)
  let bytes_read = c_read_stdin_line(buffer, buffer.length())
  if bytes_read <= 0 {
    return None
  }
  // Convert bytes to string (UTF-8)
  let chars : Array[Char] = []
  for i = 0; i < bytes_read; i = i + 1 {
    let b = buffer[i]
    // Simple ASCII handling
    if b >= 32 && b < 127 {
      chars.push(b.to_int().unsafe_to_char())
    } else if b == 10 || b == 13 {
      // Skip newlines
      continue
    }
  }
  if chars.is_empty() {
    return None
  }
  let result = StringBuilder::new()
  for c in chars {
    result.write_char(c)
  }
  Some(result.to_string())
}

///|
/// Write a line to stdout (native backend only)
fn write_stdout_line(line : String) -> Unit {
  let bytes = @utf8.encode(line + "\n")
  let _ = c_write_stdout(bytes, bytes.length())
}

///|
/// Parse JSON-RPC request from JSON
fn parse_request(json : Json) -> @interfaces.JsonRpcRequest? {
  @interfaces.JsonRpcRequest::from_json(json)
}

///|
/// Main entry point
fn main {
  // Create plugin instance
  let plugin = HelloWorldPlugin::with_defaults(name="Hello World")

  // Main loop: read JSON-RPC from stdin, write responses to stdout
  while true {
    match read_stdin_line() {
      None => break // EOF
      Some(line) =>
        if line.trim().is_empty() {
          continue
        } else {
          // Parse JSON
          let json = @json.parse(line) catch {
            _ => {
              let error_response = @interfaces.JsonRpcResponse::error(
                code=@interfaces.jsonrpc_error_parse_error(),
                message="Parse error",
                id=None,
              )
              write_stdout_line(error_response.to_json().stringify())
              continue
            }
          }
          // Parse as request
          match parse_request(json) {
            None => {
              let error_response = @interfaces.JsonRpcResponse::error(
                code=@interfaces.jsonrpc_error_invalid_request(),
                message="Invalid Request",
                id=None,
              )
              write_stdout_line(error_response.to_json().stringify())
            }
            Some(request) => {
              // Handle request
              let response = plugin.handle_request(request)
              write_stdout_line(response.to_json().stringify())
            }
          }
        }
    }
  }
}
