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
