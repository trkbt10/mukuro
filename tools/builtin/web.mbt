///|
/// Webツール - Web検索・取得（JS環境用実行コード）

///|
/// Webツールを実行（コールバックベース）
pub fn execute_web_tool(
  args : Json,
  on_result : (ToolExecutionResult) -> Unit,
) -> Unit {
  let action = match get_string_arg(args, "action") {
    Some(a) => a
    None => {
      on_result(ToolExecutionResult::error("Missing action argument"))
      return
    }
  }
  match action {
    "fetch" => {
      let url = match get_string_arg(args, "url") {
        Some(u) => u
        None => {
          on_result(ToolExecutionResult::error("Missing url argument"))
          return
        }
      }
      let http_method = get_string_arg(args, "method").unwrap_or("GET")
      let body : Bytes? = match get_string_arg(args, "body") {
        Some(b) => Some(@js.js_text_encode(b))
        None => None
      }
      let headers : Map[String, String] = {}
      // ヘッダーを設定
      match args {
        { "headers": Object(h), .. } =>
          for key, value in h {
            match value {
              String(v) => headers[key] = v
              _ => ()
            }
          }
        _ => ()
      }
      @js.fetch_with_callback(
        url,
        http_method,
        headers,
        body,
        fn(response) {
          let body_str = response.body.to_unchecked_string()
          on_result(
            ToolExecutionResult::success({
              "status": response.status,
              "body": body_str,
              "url": url,
            }),
          )
        },
        fn(error) { on_result(ToolExecutionResult::error(error)) },
      )
    }
    "search" => {
      let query = match get_string_arg(args, "query") {
        Some(q) => q
        None => {
          on_result(ToolExecutionResult::error("Missing query argument"))
          return
        }
      }
      // 注: 実際のWeb検索APIはここで実装する必要がある
      on_result(
        ToolExecutionResult::error(
          "Web search requires external API integration. Query: \{query}",
        ),
      )
    }
    _ => on_result(ToolExecutionResult::error("Unknown action: \{action}"))
  }
}
