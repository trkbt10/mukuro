///|
/// ツール定義・実行ユーティリティ

// =============================================================================
// Schema Builders
// =============================================================================

///|
/// ツール定義を作成するヘルパー
pub fn make_tool_definition(
  name~ : String,
  description~ : String,
  parameters~ : Json,
) -> @llm_types.ToolDefinition {
  @llm_types.ToolDefinition::new(name~, description~, parameters~)
}

///|
/// 文字列パラメータスキーマ
pub fn string_param(description : String) -> Json {
  { "type": "string", "description": description }
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

// =============================================================================
// Settings Schema Builders (for UI configuration)
// =============================================================================

///|
/// Settings field definition
pub(all) struct SettingsFieldDef {
  key : String
  label : String
  field_type : String // "text", "number", "toggle", "select", "secret", "textarea"
  description : String
  default_value : Json?
  options : Array[(String, String)] // for select: (value, label)
  min : Double?
  max : Double?
}

///|
/// Create a text field
pub fn text_field(
  key~ : String,
  label~ : String,
  description? : String = "",
  default_value? : String = "",
) -> SettingsFieldDef {
  {
    key,
    label,
    field_type: "text",
    description,
    default_value: if default_value == "" {
      None
    } else {
      Some(Json::string(default_value))
    },
    options: [],
    min: None,
    max: None,
  }
}

///|
/// Create a number field
pub fn number_field(
  key~ : String,
  label~ : String,
  description? : String = "",
  default_value? : Double = 0.0,
  min? : Double? = None,
  max? : Double? = None,
) -> SettingsFieldDef {
  {
    key,
    label,
    field_type: "number",
    description,
    default_value: Some(Json::number(default_value)),
    options: [],
    min,
    max,
  }
}

///|
/// Create a toggle (boolean) field
pub fn toggle_field(
  key~ : String,
  label~ : String,
  description? : String = "",
  default_value? : Bool = false,
) -> SettingsFieldDef {
  {
    key,
    label,
    field_type: "toggle",
    description,
    default_value: Some(Json::boolean(default_value)),
    options: [],
    min: None,
    max: None,
  }
}

///|
/// Create a select field
pub fn select_field(
  key~ : String,
  label~ : String,
  description? : String = "",
  default_value? : String = "",
  options~ : Array[(String, String)],
) -> SettingsFieldDef {
  {
    key,
    label,
    field_type: "select",
    description,
    default_value: if default_value == "" {
      None
    } else {
      Some(Json::string(default_value))
    },
    options,
    min: None,
    max: None,
  }
}

///|
/// Build settings schema JSON from field definitions
pub fn build_settings_schema(
  title~ : String,
  description? : String = "",
  fields~ : Array[SettingsFieldDef],
) -> Json {
  let fields_json : Array[Json] = []
  for field in fields {
    let obj : Map[String, Json] = {}
    obj["key"] = Json::string(field.key)
    obj["label"] = Json::string(field.label)
    obj["type"] = Json::string(field.field_type)
    if field.description != "" {
      obj["description"] = Json::string(field.description)
    }
    match field.default_value {
      Some(v) => obj["defaultValue"] = v
      None => ()
    }
    if field.options.length() > 0 {
      let opts : Array[Json] = []
      for opt in field.options {
        opts.push({ "value": opt.0, "label": opt.1 })
      }
      obj["options"] = Json::array(opts)
    }
    match field.min {
      Some(v) => obj["min"] = Json::number(v)
      None => ()
    }
    match field.max {
      Some(v) => obj["max"] = Json::number(v)
      None => ()
    }
    fields_json.push(Json::object(obj))
  }
  let schema : Map[String, Json] = {}
  schema["title"] = Json::string(title)
  if description != "" {
    schema["description"] = Json::string(description)
  }
  schema["fields"] = Json::array(fields_json)
  Json::object(schema)
}

// =============================================================================
// Argument Parsers
// =============================================================================

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
/// 必須の文字列引数を取得（エラー時は例外）
pub fn require_string_arg(
  args : Json,
  key : String,
) -> String raise ToolExecutionError {
  match get_string_arg(args, key) {
    Some(v) => v
    None =>
      raise ToolExecutionError::InvalidArguments(
        "Missing required argument: \{key}",
      )
  }
}

///|
/// 必須の整数引数を取得（エラー時は例外）
pub fn require_int_arg(
  args : Json,
  key : String,
) -> Int raise ToolExecutionError {
  match get_int_arg(args, key) {
    Some(v) => v
    None =>
      raise ToolExecutionError::InvalidArguments(
        "Missing required argument: \{key}",
      )
  }
}

// =============================================================================
// Workspace Path Validation
// =============================================================================

///|
/// ワークスペース境界チェック
/// workspace_dir が Some のとき、path がその配下かどうかを検証
/// 戻り値: None = OK, Some(error_message) = 拒否
pub fn validate_workspace_path(
  path : String,
  workspace_dir : String?,
) -> String? {
  match workspace_dir {
    None => None // ワークスペース制限なし
    Some(ws) => {
      // パストラバーサル
      if path.contains("..") {
        return Some("Path traversal not allowed: \{path}")
      }
      // 絶対パスの場合、ワークスペース配下かチェック
      if path.length() > 0 && char_at(path, 0) == '/' {
        if not(path.starts_with(ws)) {
          return Some(
            "Path outside workspace: \{path} (workspace: \{ws})",
          )
        }
      }
      // 相対パスは許可（ワークスペース内とみなす）
      None
    }
  }
}

// =============================================================================
// Result Types
// =============================================================================

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
} derive(Eq)

///|
/// ツール実行結果
pub(all) struct ToolExecutionResult {
  status : ToolResultStatus
  data : Json
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
