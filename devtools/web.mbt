///|
/// Webツール - Native実装（curl使用）

///|
/// Webツールを実行（Native同期版）
pub fn execute_web_tool_native(args : Json) -> @defs.ToolExecutionResult {
  let action = match @defs.get_string_arg(args, "action") {
    Some(a) => a
    None => return @defs.ToolExecutionResult::error("Missing action argument")
  }
  match action {
    "fetch" => {
      let url = match @defs.get_string_arg(args, "url") {
        Some(u) => u
        None => return @defs.ToolExecutionResult::error("Missing url argument")
      }
      let http_method = @defs.get_string_arg(args, "method").unwrap_or("GET")
      // curlコマンドを構築
      let escaped_url = escape_single_quote(url)
      let mut cmd = "curl -s -w '\\n%{http_code}' -X '\{http_method}'"
      // ヘッダーを追加
      match args {
        { "headers": Object(h), .. } =>
          for key, value in h {
            match value {
              String(v) => {
                let ek = escape_single_quote(key)
                let ev = escape_single_quote(v)
                cmd = cmd + " -H '\{ek}: \{ev}'"
              }
              _ => ()
            }
          }
        _ => ()
      }
      // ボディを追加
      match @defs.get_string_arg(args, "body") {
        Some(body) => {
          let escaped_body = escape_single_quote(body)
          cmd = cmd + " -d '\{escaped_body}'"
        }
        None => ()
      }
      cmd = cmd + " '\{escaped_url}'"
      let (stdout, exit_code) = exec_popen(cmd)
      if exit_code != 0 {
        return @defs.ToolExecutionResult::error(
          "curl failed with exit code \{exit_code}",
        )
      }
      // レスポンス解析: 最後の行がHTTPステータスコード
      let lines = stdout.split("\n").collect()
      let status_code = if lines.length() > 0 {
        let last_line = lines[lines.length() - 1].to_string().trim(
          chars=" \t\r\n",
        )
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
      @defs.ToolExecutionResult::success({
        "status": status_code,
        "body": body_buf.to_string(),
        "url": url,
      })
    }
    "search" => {
      let _query = match @defs.get_string_arg(args, "query") {
        Some(q) => q
        None => return @defs.ToolExecutionResult::error("Missing query argument")
      }
      @defs.ToolExecutionResult::error(
        "Web search requires external API integration",
      )
    }
    _ => @defs.ToolExecutionResult::error("Unknown action: \{action}")
  }
}

///|
/// ステータスコード文字列をIntにパース
fn parse_status_code(s : StringView) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}
