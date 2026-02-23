///|
/// ツール実行エラー
pub(all) suberror ToolExecutionError {
  InvalidArguments(String)
  ExecutionFailed(String)
  PermissionDenied(String)
  NotFound(String)
  Timeout
}

///|
/// ツール結果の状態
pub(all) enum ToolResultStatus {
  Success
  Error
  RequiresConfirmation
}

///|
/// ツール実行結果
pub(all) struct ToolExecutionResult {
  /// 状態
  status : ToolResultStatus
  /// 結果データ（JSON）
  data : Json
  /// エラーメッセージ（エラー時）
  error_message : String?
}

///|
/// 成功結果を作成
pub fn ToolExecutionResult::success(data : Json) -> ToolExecutionResult {
  { status: ToolResultStatus::Success, data, error_message: None }
}

///|
/// エラー結果を作成
pub fn ToolExecutionResult::error(message : String) -> ToolExecutionResult {
  { status: ToolResultStatus::Error, data: {}, error_message: Some(message) }
}

///|
/// 確認要求結果を作成
pub fn ToolExecutionResult::requires_confirmation(
  data : Json,
) -> ToolExecutionResult {
  { status: ToolResultStatus::RequiresConfirmation, data, error_message: None }
}

///|
/// JSONから文字列引数を取得
pub fn get_string_arg(args : Json, key : String) -> String? {
  match args {
    Object(obj) =>
      match obj.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// JSONから必須文字列引数を取得
pub fn require_string_arg(
  args : Json,
  key : String,
) -> String raise ToolExecutionError {
  match get_string_arg(args, key) {
    Some(s) => s
    None =>
      raise ToolExecutionError::InvalidArguments("Missing argument: \{key}")
  }
}

///|
/// JSONから整数引数を取得
pub fn get_int_arg(args : Json, key : String) -> Int? {
  match args {
    Object(obj) =>
      match obj.get(key) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

///|
/// JSONからブール引数を取得
pub fn get_bool_arg(args : Json, key : String) -> Bool? {
  match args {
    Object(obj) =>
      match obj.get(key) {
        Some(True) => Some(true)
        Some(False) => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
/// JSONから配列引数を取得
pub fn get_array_arg(args : Json, key : String) -> Array[Json]? {
  match args {
    Object(obj) =>
      match obj.get(key) {
        Some(Array(arr)) => Some(arr)
        _ => None
      }
    _ => None
  }
}

///|
/// ツール定義を作成するヘルパー
pub fn make_tool_definition(
  name~ : String,
  description~ : String,
  parameters~ : Json,
) -> @types.ToolDefinition {
  @types.ToolDefinition::new(name~, description~, parameters~)
}

///|
/// 文字列パラメータスキーマ
pub fn string_param(description : String, required : Bool) -> Json {
  if required {
    { "type": "string", "description": description }
  } else {
    { "type": "string", "description": description }
  }
}

///|
/// 整数パラメータスキーマ
pub fn integer_param(description : String) -> Json {
  { "type": "integer", "description": description }
}

///|
/// ブールパラメータスキーマ
pub fn boolean_param(description : String) -> Json {
  { "type": "boolean", "description": description }
}

///|
/// オブジェクトスキーマを作成
pub fn object_schema(properties : Json, required : Array[String]) -> Json {
  let required_json : Array[Json] = required.map(fn(s) { Json::string(s) })
  {
    "type": "object",
    "properties": properties,
    "required": Json::array(required_json),
  }
}
