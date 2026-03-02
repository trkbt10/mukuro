///|
/// Webツール - Native実装（curl使用）

// =============================================================================
// Native FFI Declarations (shared with shell/filesystem)
// =============================================================================

///|
#borrow(command, mode)
extern "C" fn web_popen_handle(command : Bytes, mode : Bytes) -> Int64 = "moonbit_popen_bytes"

///|
extern "C" fn web_pclose_handle(handle : Int64) -> Int = "moonbit_pclose_handle"

///|
#borrow(buffer)
extern "C" fn web_fread_handle(
  buffer : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fread_handle"

// =============================================================================
// Helpers
// =============================================================================

///|
fn web_escape_single_quote(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if c == '\'' {
      buf.write_string("'\\''")
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn web_utf8_to_string(data : Bytes, len : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    let b0 = data[i].to_int()
    if b0 < 0x80 {
      buf.write_char(Int::unsafe_to_char(b0))
      i = i + 1
    } else if b0 < 0xE0 {
      if i + 1 >= len {
        break
      }
      let b1 = data[i + 1].to_int()
      let cp = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i = i + 2
    } else if b0 < 0xF0 {
      if i + 2 >= len {
        break
      }
      let b1 = data[i + 1].to_int()
      let b2 = data[i + 2].to_int()
      let cp = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i = i + 3
    } else {
      if i + 3 >= len {
        break
      }
      let b1 = data[i + 1].to_int()
      let b2 = data[i + 2].to_int()
      let b3 = data[i + 3].to_int()
      let cp = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i = i + 4
    }
  }
  buf.to_string()
}

///|
fn web_exec_popen(command : String) -> (String, Int) {
  let cmd_bytes = @bytes.to_utf8_cstring(command)
  let mode_bytes = @bytes.to_utf8_cstring("r")
  let handle = web_popen_handle(cmd_bytes, mode_bytes)
  if handle == 0L {
    return ("", -1)
  }
  let buffer_size = 65536
  let buffer = Bytes::new(buffer_size)
  let bytes_read = web_fread_handle(buffer, 1, buffer_size, handle)
  let exit_raw = web_pclose_handle(handle)
  let exit_code = (exit_raw.reinterpret_as_uint() >> 8)
    .land(0xFFU)
    .reinterpret_as_int()
  let stdout = if bytes_read > 0 {
    web_utf8_to_string(buffer, bytes_read)
  } else {
    ""
  }
  (stdout, exit_code)
}

///|
fn parse_status_code(s : StringView) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}

// =============================================================================
// Platform Implementation
// =============================================================================

///|
fn web_fetch(
  url : String,
  http_method : String,
  headers : Map[String, Json]?,
  body : String?,
) -> ToolExecutionResult {
  // curlコマンドを構築
  // -L: リダイレクト追従, --max-redirs 10: 最大10回
  // --connect-timeout 10: 接続タイムアウト10秒
  // --max-time 30: 全体タイムアウト30秒
  let escaped_url = web_escape_single_quote(url)
  let mut cmd = "curl -s -L --max-redirs 10 --connect-timeout 10 --max-time 30 -w '\\n%{http_code}' -X '\{http_method}'"
  // ヘッダーを追加（User-Agentがなければデフォルトを設定）
  let mut has_user_agent = false
  match headers {
    Some(h) =>
      for key, value in h {
        match value {
          String(v) => {
            let ek = web_escape_single_quote(key)
            let ev = web_escape_single_quote(v)
            cmd = cmd + " -H '\{ek}: \{ev}'"
            if key.to_lower() == "user-agent" {
              has_user_agent = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  if not(has_user_agent) {
    cmd = cmd + " -H 'User-Agent: Mozilla/5.0 (compatible; Mukuro/1.0)'"
  }
  // ボディを追加
  match body {
    Some(b) => {
      let escaped_body = web_escape_single_quote(b)
      cmd = cmd + " -d '\{escaped_body}'"
    }
    None => ()
  }
  cmd = cmd + " '\{escaped_url}'"
  let (stdout, exit_code) = web_exec_popen(cmd)
  if exit_code != 0 {
    return ToolExecutionResult::error("curl failed with exit code \{exit_code}")
  }
  // レスポンス解析: 最後の行がHTTPステータスコード
  let lines = stdout.split("\n").collect()
  let status_code = if lines.length() > 0 {
    let last_line = lines[lines.length() - 1].to_string().trim(chars=" \t\r\n")
    parse_status_code(last_line)
  } else {
    0
  }
  // ボディは最後の行を除く
  let body_buf = StringBuilder::new()
  for i = 0; i < lines.length() - 1; i = i + 1 {
    if i > 0 {
      body_buf.write_string("\n")
    }
    body_buf.write_string(lines[i].to_string())
  }
  ToolExecutionResult::success({
    "status": status_code,
    "body": body_buf.to_string(),
    "url": url,
  })
}
