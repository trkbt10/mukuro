///|
/// 履歴レコード種別
/// Codex 互換のイベントベースモデル
pub(all) enum HistoryRecordType {
  /// セッションメタデータ（セッション開始時に1回だけ記録）
  SessionMeta
  /// ユーザーメッセージ
  UserMessage
  /// アシスタントメッセージ
  AssistantMessage
  /// ツール呼び出し
  ToolCall
  /// ツール実行結果
  ToolResult
  /// エラー
  Error
} derive(Show, Eq)

///|
/// 履歴レコード
/// JSONL形式で1行1レコードとして書き出される
pub(all) struct HistoryRecord {
  /// Unix epoch ミリ秒
  timestamp : Int64
  /// セッション識別子（channel:chat_id 形式）
  session_id : String
  /// レコード種別
  record_type : HistoryRecordType
  /// ペイロード（レコード種別ごとに異なる内容）
  payload : Json
}

///|
/// 履歴記録エラー
pub(all) suberror HistoryError {
  /// 一般的なI/Oエラー
  IoError(String)
  /// ディレクトリ作成失敗
  DirectoryCreationFailed(String)
  /// パーミッション不足
  PermissionDenied(String)
  /// ファイルが開けない
  FileOpenFailed(path~ : String, reason~ : String)
  /// 書き込み失敗
  WriteFailed(expected~ : Int, actual~ : Int)
  /// セッションが初期化されていない（open_session未呼び出し）
  NotInitialized
}

///|
pub impl Show for HistoryError with output(self, logger) {
  match self {
    IoError(msg) => logger.write_string("IoError: \{msg}")
    DirectoryCreationFailed(path) =>
      logger.write_string("DirectoryCreationFailed: \{path}")
    PermissionDenied(path) => logger.write_string("PermissionDenied: \{path}")
    FileOpenFailed(path~, reason~) =>
      logger.write_string("FileOpenFailed: \{path} (\{reason})")
    WriteFailed(expected~, actual~) =>
      logger.write_string("WriteFailed: wrote \{actual}/\{expected} bytes")
    NotInitialized =>
      logger.write_string("NotInitialized: open_session was not called")
  }
}

///|
/// 履歴レコーダー トレイト
/// セッション中のイベントを永続化する
pub(open) trait HistoryRecorder {
  /// セッション用の履歴ファイルを開く
  /// 既存ファイルがあれば追記モード、なければ新規作成
  /// 戻り値: true = 新規セッション、false = 継続セッション
  open_session(Self, session_id~ : String, timestamp~ : Int64) -> Bool raise HistoryError
  /// レコードを追記する
  record(Self, record~ : HistoryRecord) -> Unit raise HistoryError
  /// セッション終了時にファイルを閉じる
  close(Self) -> Unit raise HistoryError
}

///|
/// 履歴リーダー トレイト（ダッシュボード等で利用）
pub(open) trait HistoryReader {
  /// 指定セッションの全レコードを読み込む
  read_session(Self, session_id~ : String) -> Array[HistoryRecord] raise HistoryError
  /// 指定日のセッション一覧を取得
  list_sessions(Self, year~ : Int, month~ : Int, day~ : Int) -> Array[String] raise HistoryError
  /// 履歴がある日付一覧を取得（year, month, day のタプル配列）
  list_dates(Self) -> Array[(Int, Int, Int)] raise HistoryError
}

///|
/// 何も記録しないNoOp実装（テスト用、無効化用）
pub struct NoOpHistoryRecorder {}

///|
pub fn NoOpHistoryRecorder::new() -> NoOpHistoryRecorder {
  NoOpHistoryRecorder::{  }
}

///|
pub impl HistoryRecorder for NoOpHistoryRecorder with open_session(
  _self,
  session_id~,
  timestamp~,
) -> Bool raise HistoryError {
  ignore(session_id)
  ignore(timestamp)
  true // 常に新規セッションとして扱う
}

///|
pub impl HistoryRecorder for NoOpHistoryRecorder with record(_self, record~) -> Unit raise HistoryError {
  ignore(record)
}

///|
pub impl HistoryRecorder for NoOpHistoryRecorder with close(_self) -> Unit raise HistoryError {
  // no-op
}

///|
/// 何も返さないNoOpリーダー実装（テスト用、無効化用）
pub struct NoOpHistoryReader {}

///|
pub fn NoOpHistoryReader::new() -> NoOpHistoryReader {
  NoOpHistoryReader::{  }
}

///|
pub impl HistoryReader for NoOpHistoryReader with read_session(
  _self,
  session_id~,
) -> Array[HistoryRecord] raise HistoryError {
  ignore(session_id)
  []
}

///|
pub impl HistoryReader for NoOpHistoryReader with list_sessions(
  _self,
  year~,
  month~,
  day~,
) -> Array[String] raise HistoryError {
  ignore(year)
  ignore(month)
  ignore(day)
  []
}

///|
pub impl HistoryReader for NoOpHistoryReader with list_dates(_self) -> Array[
  (Int, Int, Int),
] raise HistoryError {
  []
}

// ============================================================
// History Metadata Store — SQLiteベースのセッションメタデータ管理
// ============================================================

///|
/// セッションメタデータ
/// SQLiteに保存されるセッションの要約情報
pub(all) struct SessionMetadata {
  /// セッション識別子（channel:chat_id 形式）
  session_id : String
  /// チャンネル名
  channel : String
  /// チャットID
  chat_id : String
  /// ユーザー指定または自動生成のタイトル
  title : String?
  /// 最初のユーザーメッセージ（プレビュー用）
  first_message : String?
  /// 総メッセージ数
  message_count : Int
  /// ユーザーメッセージ数
  user_message_count : Int
  /// アシスタントメッセージ数
  assistant_message_count : Int
  /// ツール呼び出し数
  tool_call_count : Int
  /// セッション作成時刻（Unix epoch ミリ秒）
  created_at : Int64
  /// 最終更新時刻（Unix epoch ミリ秒）
  updated_at : Int64
  /// JSONLファイルのパス（高速 read_session 用）
  file_path : String
  /// 使用モデル名
  model_name : String?
}

///|
/// メタデータストアエラー
pub(all) suberror MetadataStoreError {
  /// データベース操作エラー
  DatabaseError(String)
  /// セッションが見つからない
  NotFound(String)
  /// 無効なデータ
  InvalidData(String)
}

///|
pub impl Show for MetadataStoreError with output(self, logger) {
  match self {
    DatabaseError(msg) => logger.write_string("DatabaseError: \{msg}")
    NotFound(id) => logger.write_string("NotFound: \{id}")
    InvalidData(msg) => logger.write_string("InvalidData: \{msg}")
  }
}

///|
/// 履歴メタデータストア トレイト
/// セッションのメタデータをSQLiteで管理する
pub(open) trait HistoryMetadataStore {
  /// データベースを開く（スキーマ作成含む）
  open(Self) -> Unit raise MetadataStoreError

  /// セッションメタデータを upsert（新規または更新）
  upsert(Self, metadata~ : SessionMetadata) -> Unit raise MetadataStoreError

  /// session_id でメタデータを取得
  get(Self, session_id~ : String) -> SessionMetadata? raise MetadataStoreError

  /// メッセージカウントをインクリメント
  increment_counts(
    Self,
    session_id~ : String,
    user~ : Int,
    assistant~ : Int,
    tool~ : Int,
  ) -> Unit raise MetadataStoreError

  /// タイトルを更新
  update_title(Self, session_id~ : String, title~ : String) -> Unit raise MetadataStoreError

  /// first_message を設定（未設定の場合のみ）
  set_first_message(Self, session_id~ : String, message~ : String) -> Unit raise MetadataStoreError

  /// 日付別セッション一覧（メタデータ付き）
  list_by_date(Self, year~ : Int, month~ : Int, day~ : Int) -> Array[
    SessionMetadata,
  ] raise MetadataStoreError

  /// 最近のセッション一覧
  list_recent(Self, limit~ : Int, offset~ : Int) -> Array[SessionMetadata] raise MetadataStoreError

  /// 全文検索
  search(Self, query~ : String, limit~ : Int) -> Array[SessionMetadata] raise MetadataStoreError

  /// セッション削除
  delete(Self, session_id~ : String) -> Unit raise MetadataStoreError

  /// データベースを閉じる
  close(Self) -> Unit
}

///|
/// 何もしないNoOp実装（テスト用、無効化用）
pub struct NoOpMetadataStore {}

///|
pub fn NoOpMetadataStore::new() -> NoOpMetadataStore {
  NoOpMetadataStore::{  }
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with open(_self) -> Unit raise MetadataStoreError {
  // no-op
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with upsert(
  _self,
  metadata~,
) -> Unit raise MetadataStoreError {
  ignore(metadata)
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with get(_self, session_id~) -> SessionMetadata? raise MetadataStoreError {
  ignore(session_id)
  None
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with increment_counts(
  _self,
  session_id~,
  user~,
  assistant~,
  tool~,
) -> Unit raise MetadataStoreError {
  ignore(session_id)
  ignore(user)
  ignore(assistant)
  ignore(tool)
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with update_title(
  _self,
  session_id~,
  title~,
) -> Unit raise MetadataStoreError {
  ignore(session_id)
  ignore(title)
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with set_first_message(
  _self,
  session_id~,
  message~,
) -> Unit raise MetadataStoreError {
  ignore(session_id)
  ignore(message)
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with list_by_date(
  _self,
  year~,
  month~,
  day~,
) -> Array[SessionMetadata] raise MetadataStoreError {
  ignore(year)
  ignore(month)
  ignore(day)
  []
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with list_recent(
  _self,
  limit~,
  offset~,
) -> Array[SessionMetadata] raise MetadataStoreError {
  ignore(limit)
  ignore(offset)
  []
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with search(
  _self,
  query~,
  limit~,
) -> Array[SessionMetadata] raise MetadataStoreError {
  ignore(query)
  ignore(limit)
  []
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with delete(
  _self,
  session_id~,
) -> Unit raise MetadataStoreError {
  ignore(session_id)
}

///|
pub impl HistoryMetadataStore for NoOpMetadataStore with close(_self) -> Unit {
  // no-op
}
