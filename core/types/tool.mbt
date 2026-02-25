///|
/// ツールパラメータの型
pub(all) enum ToolParamType {
  String_
  Number
  Integer
  Boolean
  Array_(ToolParamType)
  Object(Map[String, ToolParamType])
}

///|
/// ツールパラメータ定義
pub(all) struct ToolParam {
  /// パラメータ名
  name : String
  /// 説明
  description : String
  /// 型
  param_type : ToolParamType
  /// 必須かどうか
  required : Bool
  /// デフォルト値
  default_value : Json?
}

///|
/// ツール定義（モデルに渡す形式）
pub(all) struct ToolDefinition {
  /// ツール名
  name : String
  /// 説明
  description : String
  /// パラメータ定義（JSON Schema形式）
  parameters : Json
  /// JSON Schema for validation (optional)
  schema : Json?
  /// Plugin metadata
  metadata : Map[String, String]
}

///|
/// Parameter type enum
pub(all) enum ParameterType {
  String
  Number
  Boolean
  Object
  Array
}

///|
/// Tool parameter definition
pub(all) struct ToolParameter {
  /// Parameter name
  name : String
  /// Parameter type
  param_type : ParameterType
  /// Parameter description
  description : String
  /// Whether required
  required : Bool
}

///|
/// ツールメタデータ
pub(all) struct ToolMetadata {
  /// ツール名
  name : String
  /// 説明
  description : String
  /// カテゴリ
  category : String
  /// バージョン
  version : String
  /// 必要な権限
  required_permissions : Array[String]
  /// 有効かどうか
  enabled : Bool
}

///|
/// ツール実行コンテキスト
pub(all) struct ToolContext {
  /// 現在のセッション
  session : Session
  /// 元の入力エンベロープ
  envelope : InboundEnvelope
  /// ツール固有設定
  config : Map[String, Json]
}

///|
/// ToolDefinitionを新規作成
pub fn ToolDefinition::new(
  name~ : String,
  description~ : String,
  parameters~ : Json,
) -> ToolDefinition {
  { name, description, parameters, schema: None, metadata: {} }
}

///|
/// ToolMetadataを新規作成
pub fn ToolMetadata::new(
  name~ : String,
  description~ : String,
  category~ : String,
) -> ToolMetadata {
  {
    name,
    description,
    category,
    version: "1.0.0",
    required_permissions: [],
    enabled: true,
  }
}

///|
/// JSON Schemaを構築するヘルパー
pub fn build_json_schema(
  type_~ : String,
  properties~ : Map[String, Json],
  required~ : Array[String],
) -> Json {
  {
    "type": type_,
    "properties": Json::object(properties),
    "required": Json::array(required.map(fn(s) { Json::string(s) })),
  }
}
