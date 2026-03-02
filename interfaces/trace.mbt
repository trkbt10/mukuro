///|
/// Memory Plugin Interfaces
/// 会話履歴の文脈的圧縮と想起機能のためのトレイト定義

// ============================================================
// Embedding Provider — ベクトル埋め込み生成
// ============================================================

///|
/// 埋め込み生成エラー
pub(all) suberror EmbeddingError {
  /// API呼び出しエラー
  ApiError(String)
  /// レート制限
  RateLimited(String)
  /// 無効な入力
  InvalidInput(String)
  /// 設定エラー
  ConfigError(String)
}

///|
pub impl Show for EmbeddingError with output(self, logger) {
  match self {
    ApiError(msg) => logger.write_string("EmbeddingError::ApiError: \{msg}")
    RateLimited(msg) =>
      logger.write_string("EmbeddingError::RateLimited: \{msg}")
    InvalidInput(msg) =>
      logger.write_string("EmbeddingError::InvalidInput: \{msg}")
    ConfigError(msg) =>
      logger.write_string("EmbeddingError::ConfigError: \{msg}")
  }
}

///|
/// ベクトル埋め込みプロバイダー トレイト
/// テキストをベクトル空間に埋め込む
pub(open) trait EmbeddingProvider {
  /// テキストをベクトル埋め込みに変換
  embed(Self, text : String) -> Array[Double] raise EmbeddingError

  /// 複数テキストをバッチで埋め込み（API効率化用）
  embed_batch(Self, texts : Array[String]) -> Array[Array[Double]] raise EmbeddingError

  /// 埋め込みベクトルの次元数を取得
  dimension(Self) -> Int
}

///|
/// 何もしないNoOp実装（テスト用、無効化用）
pub struct NoOpEmbeddingProvider {
  dim : Int
}

///|
pub fn NoOpEmbeddingProvider::new(dimension~ : Int) -> NoOpEmbeddingProvider {
  NoOpEmbeddingProvider::{ dim: dimension }
}

///|
pub impl EmbeddingProvider for NoOpEmbeddingProvider with embed(
  self,
  text,
) -> Array[Double] raise EmbeddingError {
  ignore(text)
  Array::make(self.dim, 0.0)
}

///|
pub impl EmbeddingProvider for NoOpEmbeddingProvider with embed_batch(
  self,
  texts,
) -> Array[Array[Double]] raise EmbeddingError {
  texts.map(fn(_) { Array::make(self.dim, 0.0) })
}

///|
pub impl EmbeddingProvider for NoOpEmbeddingProvider with dimension(self) -> Int {
  self.dim
}

// ============================================================
// Memory Store — 短期・長期記憶の永続化
// ============================================================

///|
/// メモリストアエラー
pub(all) suberror MemoryStoreError {
  /// データベース操作エラー
  DatabaseError(String)
  /// レコードが見つからない
  NotFound(String)
  /// 無効なデータ
  InvalidData(String)
  /// 圧縮エラー
  CompressionError(String)
}

///|
pub impl Show for MemoryStoreError with output(self, logger) {
  match self {
    DatabaseError(msg) =>
      logger.write_string("MemoryStoreError::DatabaseError: \{msg}")
    NotFound(id) => logger.write_string("MemoryStoreError::NotFound: \{id}")
    InvalidData(msg) =>
      logger.write_string("MemoryStoreError::InvalidData: \{msg}")
    CompressionError(msg) =>
      logger.write_string("MemoryStoreError::CompressionError: \{msg}")
  }
}

///|
/// 短期記憶エントリ
/// 1セッションの会話をLLMで短縮したもの
pub(all) struct ShortTermMemoryEntry {
  /// セッションID（channel:chat_id 形式）
  session_id : String
  /// 日付（YYYY-MM-DD 形式）
  date : String
  /// LLMで短縮した会話内容
  digest : String
  /// 抽出されたトピックキーワード
  topics : Array[String]
  /// 元の会話メッセージ数
  original_message_count : Int
  /// 推定トークン数
  estimated_tokens : Int
  /// 作成日時（Unix epoch ミリ秒）
  created_at : Int64
  /// 元の履歴ファイルパス
  source_file_path : String
}

///|
/// 長期記憶セグメント
/// 複数セッションを文脈的に分割・圧縮したもの
pub(all) struct LongTermSegment {
  /// セグメントID（UUID）
  id : String
  /// 圧縮されたコンテンツ
  content : String
  /// ベクトル埋め込み（RAG用、未生成時はNone）
  embedding : Array[Double]?
  /// 元セッションIDリスト
  source_sessions : Array[String]
  /// 時間範囲開始（Unix epoch ミリ秒）
  time_range_start : Int64
  /// 時間範囲終了（Unix epoch ミリ秒）
  time_range_end : Int64
  /// トピックキーワード
  topics : Array[String]
  /// 圧縮率（圧縮後 / 圧縮前）
  compression_ratio : Double
  /// 作成日時（Unix epoch ミリ秒）
  created_at : Int64
}

///|
/// セグメント境界
/// NCD計算で検出された意味的な区切り位置
pub(all) struct SegmentBoundary {
  /// 境界位置（文番号、0-indexed）
  position : Int
  /// NCDスコア（局所最大値、0.0-1.0）
  ncd_score : Double
}

///|
/// 日次の短期記憶集約
pub(all) struct DailyShortTermMemory {
  /// 日付（YYYY-MM-DD 形式）
  date : String
  /// その日の全セッションのダイジェスト
  entries : Array[ShortTermMemoryEntry]
  /// 合計推定トークン数
  total_tokens : Int
}

///|
/// 会話記憶ストア トレイト
/// 短期・長期記憶の永続化を担当
/// 既存の MemoryStore（key-valueストア）とは別のドメイン
pub(open) trait TraceStore {
  /// データベースを開く（スキーマ作成含む）
  open(Self) -> Unit raise MemoryStoreError

  // ---- 短期記憶操作 ----

  /// 短期記憶エントリを保存
  save_short_term(Self, entry : ShortTermMemoryEntry) -> Unit raise MemoryStoreError

  /// 日付で短期記憶を取得
  get_daily_memory(Self, date : String) -> Array[ShortTermMemoryEntry] raise MemoryStoreError

  /// 最近N日分の短期記憶を取得
  list_recent_short_term(Self, days : Int) -> Array[ShortTermMemoryEntry] raise MemoryStoreError

  /// セッションIDで短期記憶を取得
  get_short_term_by_session(Self, session_id : String) -> ShortTermMemoryEntry? raise MemoryStoreError

  /// 短期記憶を削除（長期記憶への移行後）
  delete_short_term(Self, session_id : String) -> Unit raise MemoryStoreError

  // ---- 長期記憶操作 ----

  /// 長期記憶セグメントを保存
  save_segment(Self, segment : LongTermSegment) -> Unit raise MemoryStoreError

  /// IDでセグメントを取得
  get_segment(Self, id : String) -> LongTermSegment? raise MemoryStoreError

  /// ベクトル類似検索（RAG用）
  search_segments_by_vector(
    Self,
    embedding : Array[Double],
    limit : Int,
  ) -> Array[(LongTermSegment, Double)] raise MemoryStoreError

  /// 時間範囲でセグメントを取得
  get_segments_by_time(
    Self,
    start : Int64,
    end : Int64,
  ) -> Array[LongTermSegment] raise MemoryStoreError

  /// トピックでセグメントを検索
  search_segments_by_topic(
    Self,
    topics : Array[String],
    limit : Int,
  ) -> Array[LongTermSegment] raise MemoryStoreError

  /// セグメントを削除
  delete_segment(Self, id : String) -> Unit raise MemoryStoreError

  /// データベースを閉じる
  close(Self) -> Unit
}

///|
/// 何もしないNoOp実装（テスト用、無効化用）
pub struct NoOpTraceStore {}

///|
pub fn NoOpTraceStore::new() -> NoOpTraceStore {
  NoOpTraceStore::{  }
}

///|
pub impl TraceStore for NoOpTraceStore with open(_self) -> Unit raise MemoryStoreError {
  // no-op
}

///|
pub impl TraceStore for NoOpTraceStore with save_short_term(
  _self,
  entry,
) -> Unit raise MemoryStoreError {
  ignore(entry)
}

///|
pub impl TraceStore for NoOpTraceStore with get_daily_memory(
  _self,
  date,
) -> Array[ShortTermMemoryEntry] raise MemoryStoreError {
  ignore(date)
  []
}

///|
pub impl TraceStore for NoOpTraceStore with list_recent_short_term(
  _self,
  days,
) -> Array[ShortTermMemoryEntry] raise MemoryStoreError {
  ignore(days)
  []
}

///|
pub impl TraceStore for NoOpTraceStore with get_short_term_by_session(
  _self,
  session_id,
) -> ShortTermMemoryEntry? raise MemoryStoreError {
  ignore(session_id)
  None
}

///|
pub impl TraceStore for NoOpTraceStore with delete_short_term(
  _self,
  session_id,
) -> Unit raise MemoryStoreError {
  ignore(session_id)
}

///|
pub impl TraceStore for NoOpTraceStore with save_segment(
  _self,
  segment,
) -> Unit raise MemoryStoreError {
  ignore(segment)
}

///|
pub impl TraceStore for NoOpTraceStore with get_segment(
  _self,
  id,
) -> LongTermSegment? raise MemoryStoreError {
  ignore(id)
  None
}

///|
pub impl TraceStore for NoOpTraceStore with search_segments_by_vector(
  _self,
  embedding,
  limit,
) -> Array[(LongTermSegment, Double)] raise MemoryStoreError {
  ignore(embedding)
  ignore(limit)
  []
}

///|
pub impl TraceStore for NoOpTraceStore with get_segments_by_time(
  _self,
  start,
  end,
) -> Array[LongTermSegment] raise MemoryStoreError {
  ignore(start)
  ignore(end)
  []
}

///|
pub impl TraceStore for NoOpTraceStore with search_segments_by_topic(
  _self,
  topics,
  limit,
) -> Array[LongTermSegment] raise MemoryStoreError {
  ignore(topics)
  ignore(limit)
  []
}

///|
pub impl TraceStore for NoOpTraceStore with delete_segment(
  _self,
  id,
) -> Unit raise MemoryStoreError {
  ignore(id)
}

///|
pub impl TraceStore for NoOpTraceStore with close(_self) -> Unit {
  // no-op
}

// ============================================================
// Memory Service — 記憶処理の高レベルAPI
// ============================================================

///|
/// ダイジェスト設定
pub(all) struct DigestConfig {
  /// 目標圧縮率（0.0-1.0、例: 0.3 = 30%に圧縮）
  target_ratio : Double
  /// キーワード保持（技術用語、固有名詞を保持）
  preserve_key_terms : Bool
  /// 構造保持（見出し、箇条書きを保持）
  preserve_structure : Bool
}

///|
pub fn DigestConfig::default() -> DigestConfig {
  { target_ratio: 0.3, preserve_key_terms: true, preserve_structure: true }
}

///|
/// 想起結果
pub(all) struct RecallResult {
  /// マッチしたセグメントまたは短期記憶
  content : String
  /// 関連度スコア（0.0-1.0）
  relevance : Double
  /// 元セッションIDリスト
  source_sessions : Array[String]
  /// 時間範囲
  time_range : (Int64, Int64)?
  /// ソースタイプ
  source_type : RecallSourceType
}

///|
/// 想起ソースタイプ
pub(all) enum RecallSourceType {
  /// 短期記憶（当日〜数日前）
  ShortTerm
  /// 長期記憶（圧縮済み）
  LongTerm
} derive(Show, Eq)
