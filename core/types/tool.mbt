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
