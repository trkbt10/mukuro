///|
/// スキル定義
pub(all) struct SkillDefinition {
  /// スキル名
  name : String
  /// 説明
  description : String
  /// 指示内容
  instructions : String
}

///|
/// コンテキスト構築入力
pub(all) struct ContextInput {
  /// セッション履歴
  session_history : Array[@types.ModelMessage]
  /// 長期記憶からの関連情報
  memory_context : Array[String]
  /// 利用可能スキル定義
  skills : Array[SkillDefinition]
  /// ブートストラップ指示（システムプロンプト）
  bootstrap : String
  /// 現在の入力メッセージ
  current_message : @types.InboundEnvelope
}

///|
/// コンテキスト構築トレイト
/// セッション履歴やメモリからモデルメッセージ列を構築する
pub(open) trait ContextBuilder {
  /// コンテキストからモデルメッセージ列を構築
  build(Self, ContextInput) -> Array[@types.ModelMessage]
}

///|
/// メモリストアトレイト
/// 長期記憶の保存・取得を担当する
pub(open) trait MemoryStore {
  /// 記憶を保存
  store(Self, key~ : String, value~ : String) -> Unit raise
  /// 記憶を取得
  retrieve(Self, key~ : String) -> String? raise
  /// 関連する記憶を検索
  search(Self, query~ : String, limit~ : Int) -> Array[String] raise
  /// 記憶を削除
  remove(Self, key~ : String) -> Unit raise
}
