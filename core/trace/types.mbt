///|
/// Memory Plugin Types — 型の Json 変換とヘルパー関数

// ============================================================
// ShortTermMemoryEntry の Json 変換
// ============================================================

///|
/// ShortTermMemoryEntry を Json に変換
pub fn short_term_entry_to_json(entry : @interfaces.ShortTermMemoryEntry) -> Json {
  let topics_json = entry.topics.map(fn(t) { Json::string(t) })
  Json::object({
    "session_id": Json::string(entry.session_id),
    "date": Json::string(entry.date),
    "digest": Json::string(entry.digest),
    "topics": Json::array(topics_json),
    "original_message_count": Json::number(entry.original_message_count.to_double()),
    "estimated_tokens": Json::number(entry.estimated_tokens.to_double()),
    "created_at": Json::number(entry.created_at.to_double()),
    "source_file_path": Json::string(entry.source_file_path),
  })
}

///|
/// Json から ShortTermMemoryEntry を復元
pub fn short_term_entry_from_json(
  json : Json
) -> @interfaces.ShortTermMemoryEntry? {
  let obj = match json {
    Object(o) => o
    _ => return None
  }
  let session_id = match obj.get("session_id") {
    Some(String(s)) => s
    _ => return None
  }
  let date = match obj.get("date") {
    Some(String(s)) => s
    _ => return None
  }
  let digest = match obj.get("digest") {
    Some(String(s)) => s
    _ => return None
  }
  let topics = match obj.get("topics") {
    Some(Array(arr)) =>
      arr.filter_map(
        fn(j) {
          match j {
            String(s) => Some(s)
            _ => None
          }
        },
      )
    _ => []
  }
  let original_message_count = match obj.get("original_message_count") {
    Some(Number(n, ..)) => n.to_int()
    _ => 0
  }
  let estimated_tokens = match obj.get("estimated_tokens") {
    Some(Number(n, ..)) => n.to_int()
    _ => 0
  }
  let created_at = match obj.get("created_at") {
    Some(Number(n, ..)) => n.to_int64()
    _ => 0L
  }
  let source_file_path = match obj.get("source_file_path") {
    Some(String(s)) => s
    _ => ""
  }
  Some(
    {
      session_id,
      date,
      digest,
      topics,
      original_message_count,
      estimated_tokens,
      created_at,
      source_file_path,
    },
  )
}

// ============================================================
// LongTermSegment の Json 変換
// ============================================================

///|
/// LongTermSegment を Json に変換
pub fn segment_to_json(segment : @interfaces.LongTermSegment) -> Json {
  let topics_json = segment.topics.map(fn(t) { Json::string(t) })
  let sources_json = segment.source_sessions.map(fn(s) { Json::string(s) })
  let embedding_json : Json = match segment.embedding {
    Some(emb) => Json::array(emb.map(fn(v) { Json::number(v) }))
    None => Json::null()
  }
  Json::object({
    "id": Json::string(segment.id),
    "content": Json::string(segment.content),
    "embedding": embedding_json,
    "source_sessions": Json::array(sources_json),
    "time_range_start": Json::number(segment.time_range_start.to_double()),
    "time_range_end": Json::number(segment.time_range_end.to_double()),
    "topics": Json::array(topics_json),
    "compression_ratio": Json::number(segment.compression_ratio),
    "created_at": Json::number(segment.created_at.to_double()),
  })
}

///|
/// Json から LongTermSegment を復元
pub fn segment_from_json(json : Json) -> @interfaces.LongTermSegment? {
  let obj = match json {
    Object(o) => o
    _ => return None
  }
  let id = match obj.get("id") {
    Some(String(s)) => s
    _ => return None
  }
  let content = match obj.get("content") {
    Some(String(s)) => s
    _ => return None
  }
  let embedding : Array[Double]? = match obj.get("embedding") {
    Some(Array(arr)) =>
      Some(
        arr.filter_map(
          fn(j) {
            match j {
              Number(n, ..) => Some(n)
              _ => None
            }
          },
        ),
      )
    Some(Null) => None
    None => None
    _ => None
  }
  let source_sessions = match obj.get("source_sessions") {
    Some(Array(arr)) =>
      arr.filter_map(
        fn(j) {
          match j {
            String(s) => Some(s)
            _ => None
          }
        },
      )
    _ => []
  }
  let time_range_start = match obj.get("time_range_start") {
    Some(Number(n, ..)) => n.to_int64()
    _ => 0L
  }
  let time_range_end = match obj.get("time_range_end") {
    Some(Number(n, ..)) => n.to_int64()
    _ => 0L
  }
  let topics = match obj.get("topics") {
    Some(Array(arr)) =>
      arr.filter_map(
        fn(j) {
          match j {
            String(s) => Some(s)
            _ => None
          }
        },
      )
    _ => []
  }
  let compression_ratio = match obj.get("compression_ratio") {
    Some(Number(n, ..)) => n
    _ => 1.0
  }
  let created_at = match obj.get("created_at") {
    Some(Number(n, ..)) => n.to_int64()
    _ => 0L
  }
  Some(
    {
      id,
      content,
      embedding,
      source_sessions,
      time_range_start,
      time_range_end,
      topics,
      compression_ratio,
      created_at,
    },
  )
}

// ============================================================
// NCD Segmentation 用の追加型
// ============================================================

///|
/// 文（センテンス）
/// 元テキストから分割された単位
pub(all) struct Sentence {
  /// 0-indexed の文番号
  index : Int
  /// 文テキスト（トリム済み）
  text : String
  /// 元テキストでの開始位置
  start : Int
  /// 元テキストでの終了位置（exclusive）
  end : Int
}

///|
/// NCD ウィンドウ結果
/// スライディングウィンドウで計算された NCD 値と位置
pub(all) struct NcdWindowResult {
  /// 隣接ウィンドウ間の NCD 値
  ncd_values : Array[Double]
  /// 各ウィンドウの終了位置（文字位置）
  window_end_positions : Array[Int]
}

///|
/// セグメンテーション設定
pub(all) struct SegmentationConfig {
  /// 目標チャンクサイズ（文字数）
  target_chunk_size : Int
  /// 最小チャンクサイズ（文字数）
  min_chunk_size : Int
  /// 最大チャンクサイズ（文字数）
  max_chunk_size : Int
  /// NCD 閾値（これ以上の NCD を境界候補とする）
  ncd_threshold : Double
  /// スライディングウィンドウサイズ（文数）
  window_size : Int
  /// 適応モードを使用するか（true = NCD ピークベース、false = 目標サイズベース）
  adaptive : Bool
  /// 適応モードでの NCD パーセンタイル（上位何%を境界とするか）
  ncd_percentile : Double
}

///|
pub fn SegmentationConfig::default() -> SegmentationConfig {
  {
    target_chunk_size: 500,
    min_chunk_size: 100,
    max_chunk_size: 2000,
    ncd_threshold: 0.4,
    window_size: 3,
    adaptive: false,
    ncd_percentile: 0.2,
  }
}

// ============================================================
// ダイジェスト処理用の型
// ============================================================

///|
/// ダイジェストコンテキストタイプ
pub(all) enum DigestContextType {
  /// 一般的な会話
  Conversation
  /// ドキュメント
  Document
  /// ノート・メモ
  Notes
} derive(Show, Eq)

///|
/// バッチダイジェスト設定
pub(all) struct BatchDigestConfig {
  /// バッチ対象とする閾値（この文字数以下をバッチ候補に）
  batch_threshold : Int
  /// 最大バッチサイズ（セグメント数）
  max_batch_size : Int
  /// 最大バッチ文字数
  max_batch_chars : Int
}

///|
pub fn BatchDigestConfig::default() -> BatchDigestConfig {
  { batch_threshold: 300, max_batch_size: 5, max_batch_chars: 1500 }
}

///|
/// 反復ダイジェスト設定
pub(all) struct IterativeDigestConfig {
  /// 目標圧縮率
  target_ratio : Double
  /// 最大反復回数
  max_iterations : Int
  /// 収束閾値（この比率以上の削減で継続、以下で停止）
  convergence_threshold : Double
}

///|
pub fn IterativeDigestConfig::default() -> IterativeDigestConfig {
  { target_ratio: 0.3, max_iterations: 5, convergence_threshold: 0.05 }
}

// ============================================================
// トークン推定
// ============================================================

///|
/// テキストのトークン数を推定（簡易）
/// 日本語: 約1.5文字/トークン、英語: 約4文字/トークン
/// 混合テキストの概算として 2文字/トークン を使用
pub fn estimate_tokens(text : String) -> Int {
  let len = text.iter().count()
  if len == 0 {
    0
  } else {
    (len + 1) / 2 // 2文字で1トークンとして概算
  }
}
