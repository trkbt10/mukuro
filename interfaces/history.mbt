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
  IoError(String)
  DirectoryCreationFailed(String)
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
pub impl HistoryReader for NoOpHistoryReader with list_dates(_self) -> Array[(Int, Int, Int)] raise HistoryError {
  []
}
