///|
/// ツール実行結果
pub(all) enum ToolResult {
  /// 成功
  Success(content~ : String)
  /// エラー
  Error(message~ : String)
  /// 追加のツール呼び出しが必要
  RequiresAction(next_tool~ : String, arguments~ : Json)
}
