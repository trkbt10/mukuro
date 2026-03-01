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
/// ワークスペースコンテキストファイル（OpenClaw互換）
pub(all) struct ContextFiles {
  /// SOUL.md - AIの性格・価値観定義
  soul : String?
  /// AGENTS.md - ワークスペースハンドブック/行動指針
  agents_handbook : String?
  /// TOOLS.md - ローカル環境・ツール設定
  tools_config : String?
  /// IDENTITY.md - AIの名前・アイデンティティ
  identity : String?
  /// USER.md - ユーザー情報・好み
  user_context : String?
  /// HEARTBEAT.md - 定期タスクチェックリスト
  heartbeat : String?
}

///|
/// 空のContextFilesを作成
pub fn ContextFiles::empty() -> ContextFiles {
  {
    soul: None,
    agents_handbook: None,
    tools_config: None,
    identity: None,
    user_context: None,
    heartbeat: None,
  }
}

///|
/// SOUL.mdが設定されているかどうか
pub fn ContextFiles::has_soul(self : ContextFiles) -> Bool {
  match self.soul {
    Some(s) => s.trim(chars=" \t\n\r").length() > 0
    None => false
  }
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
  /// システムプロンプト設定（OpenClaw互換）
  system_prompt_config : @types.SystemPromptConfig?
  /// 会話中の最初のメッセージかどうか（SystemPromptWhen::First用）
  is_first_message : Bool
  /// ワークスペースコンテキストファイル（OpenClaw互換）
  context_files : ContextFiles
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
