///|
/// Short-Term Memory Module
/// セッション終了時に会話をLLMで短縮し、短期記憶として保存
///
/// Short-Term Memory は当日〜数日の会話記録を保持し、
/// システムプロンプトに注入することで会話の継続性を実現する

// ============================================================
// ShortTermMemoryError
// ============================================================

///|
/// 短期記憶エラー
pub(all) suberror ShortTermMemoryError {
  /// ストア操作エラー
  StoreError(String)
  /// ダイジェスト処理エラー
  DigestFailure(String)
  /// 履歴読み込みエラー
  HistoryReadError(String)
  /// セッションが見つからない
  SessionNotFound(String)
}

///|
pub impl Show for ShortTermMemoryError with output(self, logger) {
  match self {
    StoreError(msg) => logger.write_string("ShortTermMemoryError::StoreError: \{msg}")
    DigestFailure(msg) =>
      logger.write_string("ShortTermMemoryError::DigestFailure: \{msg}")
    HistoryReadError(msg) =>
      logger.write_string("ShortTermMemoryError::HistoryReadError: \{msg}")
    SessionNotFound(id) =>
      logger.write_string("ShortTermMemoryError::SessionNotFound: \{id}")
  }
}

// ============================================================
// ShortTermMemoryService
// ============================================================

///|
/// 短期記憶サービス設定
pub(all) struct ShortTermMemoryConfig {
  /// 最近N日分を保持
  recent_days : Int
  /// システムプロンプトに含める最大エントリ数
  max_prompt_entries : Int
  /// システムプロンプトに含める最大トークン数
  max_prompt_tokens : Int
}

///|
pub fn ShortTermMemoryConfig::default() -> ShortTermMemoryConfig {
  { recent_days: 3, max_prompt_entries: 10, max_prompt_tokens: 2000 }
}

///|
/// 短期記憶サービス
/// セッションの短縮と保存、想起を担当
pub struct ShortTermMemoryService {
  config : ShortTermMemoryConfig
  digest_service : DigestService
}

///|
pub fn ShortTermMemoryService::new(
  config~ : ShortTermMemoryConfig,
  digest_config~ : DigestServiceConfig,
) -> ShortTermMemoryService {
  {
    config,
    digest_service: DigestService::new(config=digest_config),
  }
}

///|
pub fn ShortTermMemoryService::with_defaults() -> ShortTermMemoryService {
  ShortTermMemoryService::new(
    config=ShortTermMemoryConfig::default(),
    digest_config=DigestServiceConfig::default(),
  )
}

// ============================================================
// Core Operations
// ============================================================

///|
/// セッションメッセージから短期記憶エントリを作成
/// セッション終了時に呼び出す
pub async fn ShortTermMemoryService::create_entry_from_messages(
  self : ShortTermMemoryService,
  orchestrator : &@interfaces.ModelOrchestrator,
  session_id : String,
  date : String,
  messages : Array[@types.ModelMessage],
  source_file_path : String,
  timestamp : Int64,
) -> @interfaces.ShortTermMemoryEntry raise ShortTermMemoryError {
  // メッセージが空の場合はエラー
  if messages.is_empty() {
    raise SessionNotFound("No messages in session: \{session_id}")
  }
  // DigestService を使ってエントリを作成
  let entry = self.digest_service.create_short_term_entry(
      orchestrator,
      session_id,
      date,
      messages,
      source_file_path,
      timestamp,
    )
    catch {
      e => raise DigestFailure(e.to_string())
    }
  entry
}

///|
/// 短期記憶エントリをストアに保存
pub fn ShortTermMemoryService::save_entry(
  _self : ShortTermMemoryService,
  store : &@interfaces.TraceStore,
  entry : @interfaces.ShortTermMemoryEntry,
) -> Unit raise ShortTermMemoryError {
  store.save_short_term(entry) catch {
    e => raise StoreError(e.to_string())
  }
}

///|
/// セッションの短期記憶を取得
pub fn ShortTermMemoryService::get_entry_by_session(
  _self : ShortTermMemoryService,
  store : &@interfaces.TraceStore,
  session_id : String,
) -> @interfaces.ShortTermMemoryEntry? raise ShortTermMemoryError {
  store.get_short_term_by_session(session_id) catch {
    e => raise StoreError(e.to_string())
  }
}

///|
/// 指定日の短期記憶を取得
pub fn ShortTermMemoryService::get_daily_entries(
  _self : ShortTermMemoryService,
  store : &@interfaces.TraceStore,
  date : String,
) -> Array[@interfaces.ShortTermMemoryEntry] raise ShortTermMemoryError {
  store.get_daily_memory(date) catch {
    e => raise StoreError(e.to_string())
  }
}

///|
/// 最近N日分の短期記憶を取得
pub fn ShortTermMemoryService::get_recent_entries(
  self : ShortTermMemoryService,
  store : &@interfaces.TraceStore,
) -> Array[@interfaces.ShortTermMemoryEntry] raise ShortTermMemoryError {
  store.list_recent_short_term(self.config.recent_days) catch {
    e => raise StoreError(e.to_string())
  }
}

///|
/// 短期記憶を削除（長期記憶への移行後など）
pub fn ShortTermMemoryService::delete_entry(
  _self : ShortTermMemoryService,
  store : &@interfaces.TraceStore,
  session_id : String,
) -> Unit raise ShortTermMemoryError {
  store.delete_short_term(session_id) catch {
    e => raise StoreError(e.to_string())
  }
}

// ============================================================
// System Prompt Integration
// ============================================================

///|
/// 短期記憶をシステムプロンプト用テキストに変換
/// トークン制限を考慮して最近のエントリから優先的に含める
pub fn ShortTermMemoryService::format_for_prompt(
  self : ShortTermMemoryService,
  entries : Array[@interfaces.ShortTermMemoryEntry],
) -> String {
  if entries.is_empty() {
    return ""
  }
  // 時間降順でソート（最新が先）
  let sorted = entries.copy()
  sorted.sort_by(
    fn(a, b) {
      if a.created_at > b.created_at {
        -1
      } else if a.created_at < b.created_at {
        1
      } else {
        0
      }
    },
  )
  let parts : Array[String] = []
  let mut total_tokens = 0
  let mut count = 0
  for entry in sorted {
    // 制限チェック
    if count >= self.config.max_prompt_entries {
      break
    }
    if total_tokens + entry.estimated_tokens > self.config.max_prompt_tokens {
      break
    }
    // エントリをフォーマット
    let formatted = format_entry_for_prompt(entry)
    parts.push(formatted)
    total_tokens = total_tokens + entry.estimated_tokens
    count = count + 1
  }
  if parts.is_empty() {
    ""
  } else {
    let header = "## Recent Conversations\n\n"
    header + parts.join("\n\n---\n\n")
  }
}

///|
/// 単一エントリをプロンプト用にフォーマット
fn format_entry_for_prompt(entry : @interfaces.ShortTermMemoryEntry) -> String {
  let topics_str = if entry.topics.is_empty() {
    ""
  } else {
    " (" + entry.topics.join(", ") + ")"
  }
  "**\{entry.date}**\{topics_str}\n\{entry.digest}"
}

///|
/// ストアから短期記憶を取得してプロンプト用テキストを生成
pub fn ShortTermMemoryService::get_prompt_context(
  self : ShortTermMemoryService,
  store : &@interfaces.TraceStore,
) -> String raise ShortTermMemoryError {
  let entries = self.get_recent_entries(store)
  self.format_for_prompt(entries)
}

// ============================================================
// Internal Tests
// ============================================================

test "ShortTermMemoryConfig default values" {
  let config = ShortTermMemoryConfig::default()
  assert_eq(config.recent_days, 3)
  assert_eq(config.max_prompt_entries, 10)
  assert_eq(config.max_prompt_tokens, 2000)
}

test "ShortTermMemoryService creation" {
  let service = ShortTermMemoryService::with_defaults()
  assert_eq(service.config.recent_days, 3)
}

test "format_entry_for_prompt without topics" {
  let entry : @interfaces.ShortTermMemoryEntry = {
    session_id: "test:123",
    date: "2026-03-02",
    digest: "Test digest content",
    topics: [],
    original_message_count: 10,
    estimated_tokens: 50,
    created_at: 1709337600000L,
    source_file_path: "",
  }
  let formatted = format_entry_for_prompt(entry)
  assert_true(formatted.contains("**2026-03-02**"))
  assert_true(formatted.contains("Test digest content"))
  assert_false(formatted.contains("("))
}

test "format_entry_for_prompt with topics" {
  let entry : @interfaces.ShortTermMemoryEntry = {
    session_id: "test:123",
    date: "2026-03-02",
    digest: "Test digest content",
    topics: ["MoonBit", "FFI"],
    original_message_count: 10,
    estimated_tokens: 50,
    created_at: 1709337600000L,
    source_file_path: "",
  }
  let formatted = format_entry_for_prompt(entry)
  assert_true(formatted.contains("**2026-03-02**"))
  assert_true(formatted.contains("(MoonBit, FFI)"))
  assert_true(formatted.contains("Test digest content"))
}

test "format_for_prompt with empty entries" {
  let service = ShortTermMemoryService::with_defaults()
  let result = service.format_for_prompt([])
  assert_eq(result, "")
}

test "format_for_prompt respects token limit" {
  let config = ShortTermMemoryConfig::{
    recent_days: 3,
    max_prompt_entries: 10,
    max_prompt_tokens: 100, // 100トークン制限
  }
  let service = ShortTermMemoryService::new(
    config=config,
    digest_config=DigestServiceConfig::default(),
  )
  let entries : Array[@interfaces.ShortTermMemoryEntry] = [
    {
      session_id: "test:1",
      date: "2026-03-02",
      digest: "First entry",
      topics: [],
      original_message_count: 5,
      estimated_tokens: 60,
      created_at: 1709337600000L,
      source_file_path: "",
    },
    {
      session_id: "test:2",
      date: "2026-03-01",
      digest: "Second entry",
      topics: [],
      original_message_count: 5,
      estimated_tokens: 60, // これを足すと120 > 100 なので含まれない
      created_at: 1709251200000L,
      source_file_path: "",
    },
  ]
  let result = service.format_for_prompt(entries)
  assert_true(result.contains("First entry"))
  assert_false(result.contains("Second entry"))
}

test "format_for_prompt respects entry count limit" {
  let config = ShortTermMemoryConfig::{
    recent_days: 3,
    max_prompt_entries: 1, // 1エントリ制限
    max_prompt_tokens: 10000,
  }
  let service = ShortTermMemoryService::new(
    config=config,
    digest_config=DigestServiceConfig::default(),
  )
  let entries : Array[@interfaces.ShortTermMemoryEntry] = [
    {
      session_id: "test:1",
      date: "2026-03-02",
      digest: "First entry",
      topics: [],
      original_message_count: 5,
      estimated_tokens: 10,
      created_at: 1709337600000L,
      source_file_path: "",
    },
    {
      session_id: "test:2",
      date: "2026-03-01",
      digest: "Second entry",
      topics: [],
      original_message_count: 5,
      estimated_tokens: 10,
      created_at: 1709251200000L,
      source_file_path: "",
    },
  ]
  let result = service.format_for_prompt(entries)
  assert_true(result.contains("First entry"))
  assert_false(result.contains("Second entry"))
}

test "format_for_prompt orders by created_at descending" {
  let service = ShortTermMemoryService::with_defaults()
  let entries : Array[@interfaces.ShortTermMemoryEntry] = [
    {
      session_id: "older",
      date: "2026-03-01",
      digest: "Older entry",
      topics: [],
      original_message_count: 5,
      estimated_tokens: 10,
      created_at: 1709251200000L, // earlier
      source_file_path: "",
    },
    {
      session_id: "newer",
      date: "2026-03-02",
      digest: "Newer entry",
      topics: [],
      original_message_count: 5,
      estimated_tokens: 10,
      created_at: 1709337600000L, // later
      source_file_path: "",
    },
  ]
  let result = service.format_for_prompt(entries)
  // Newer entry should appear first
  let newer_pos = result.find("Newer entry")
  let older_pos = result.find("Older entry")
  match (newer_pos, older_pos) {
    (Some(n), Some(o)) => assert_true(n < o)
    _ => assert_true(false)
  }
}

test "ShortTermMemoryError display" {
  let err : ShortTermMemoryError = ShortTermMemoryError::StoreError("test")
  assert_true(err.to_string().contains("StoreError"))
  let err2 : ShortTermMemoryError = ShortTermMemoryError::SessionNotFound("sess1")
  assert_true(err2.to_string().contains("SessionNotFound"))
}
