///|
/// MCP (Model Context Protocol) サーバー設定

///|
/// MCP サーバー設定
pub(all) struct McpServerConfig {
  /// サーバー名（識別用）
  name : String
  /// 実行コマンド
  command : String
  /// コマンド引数
  args : Array[String]
  /// 環境変数
  env : Map[String, String]
  /// 作業ディレクトリ
  cwd : String?
}

///|
/// MCP サーバー設定をJSONからパース
pub fn McpServerConfig::from_json(
  name : String,
  json : Json,
) -> McpServerConfig? {
  match json {
    { "command": String(command), .. } => {
      let args : Array[String] = match json {
        { "args": Array(arr), .. } => {
          let result : Array[String] = []
          for item in arr {
            match item {
              String(s) => result.push(s)
              _ => ()
            }
          }
          result
        }
        _ => []
      }
      let env : Map[String, String] = {}
      match json {
        { "env": Object(obj), .. } =>
          for key, value in obj {
            match value {
              String(v) => env[key] = v
              _ => ()
            }
          }
        _ => ()
      }
      let cwd = match json {
        { "cwd": String(c), .. } => Some(c)
        _ => None
      }
      Some({ name, command, args, env, cwd })
    }
    _ => None
  }
}

///|
/// MCP ツール定義 (サーバーから受け取る)
pub(all) struct McpToolDef {
  /// ツール名
  name : String
  /// 説明
  description : String
  /// パラメータスキーマ (JSON Schema)
  input_schema : Json
  /// 所属する MCP サーバー名
  server_name : String
}

///|
/// McpToolDef を llm_interop の ToolDefinition に変換
pub fn McpToolDef::to_tool_definition(self : McpToolDef) -> @llm_types.ToolDefinition {
  @llm_types.ToolDefinition::new(
    name="mcp_\{self.server_name}_\{self.name}",
    description="[MCP:\{self.server_name}] \{self.description}",
    parameters=self.input_schema,
  )
}
