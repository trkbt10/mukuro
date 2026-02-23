///|
/// ツール呼び出しリクエスト
pub(all) struct ToolCallRequest {
  /// 呼び出しID
  id : String
  /// ツール名
  name : String
  /// 引数（JSON形式）
  arguments : Json
}

///|
/// モデルに送信するメッセージ
pub(all) enum ModelMessage {
  /// システムメッセージ
  System(String)
  /// ユーザーメッセージ
  User(content~ : String, name~ : String?)
  /// アシスタントメッセージ
  Assistant(content~ : String, tool_calls~ : Array[ToolCallRequest]?)
  /// ツール実行結果
  ToolResult(tool_call_id~ : String, content~ : String)
}

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

///|
/// モデル応答
pub(all) enum ModelResponse {
  /// テキスト応答
  Text(String)
  /// ツール呼び出し要求
  ToolCalls(Array[ToolCallRequest])
  /// エラー
  ModelError(String)
  /// レート制限
  RateLimited(retry_after~ : Int)
}

///|
/// ToolCallRequestのデフォルト値を生成
pub fn ToolCallRequest::default() -> ToolCallRequest {
  { id: "", name: "", arguments: Json::null() }
}

///|
/// ToolCallRequestを新規作成
pub fn ToolCallRequest::new(
  id~ : String,
  name~ : String,
  arguments~ : Json,
) -> ToolCallRequest {
  { id, name, arguments }
}
