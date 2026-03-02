///|
/// Digest Module — LLM-based Text Shortening
/// テキストの意味を保持しながら冗長な表現を削除
///
/// 重要: これは「要約 (summarize)」ではなく「短縮 (shorten)」
/// - 要約: 主要なポイントを抽出して新しい文を生成
/// - 短縮: 元の表現を維持しながら冗長性を削除

// ============================================================
// DigestError
// ============================================================

///|
/// ダイジェスト処理エラー
pub(all) suberror DigestError {
  /// モデル呼び出しエラー
  ModelCallError(String)
  /// 入力が空
  EmptyInput
  /// パースエラー
  ParseError(String)
  /// 設定エラー
  ConfigError(String)
}

///|
pub impl Show for DigestError with output(self, logger) {
  match self {
    ModelCallError(msg) =>
      logger.write_string("DigestError::ModelCallError: \{msg}")
    EmptyInput => logger.write_string("DigestError::EmptyInput")
    ParseError(msg) => logger.write_string("DigestError::ParseError: \{msg}")
    ConfigError(msg) => logger.write_string("DigestError::ConfigError: \{msg}")
  }
}

// ============================================================
// DigestService
// ============================================================

///|
/// ダイジェストサービス設定
pub(all) struct DigestServiceConfig {
  /// 反復ダイジェスト設定
  iterative : IterativeDigestConfig
  /// バッチダイジェスト設定
  batch : BatchDigestConfig
  /// モデルオプション（温度など）
  model_options : @types.ModelOptions
}

///|
pub fn DigestServiceConfig::default() -> DigestServiceConfig {
  {
    iterative: IterativeDigestConfig::default(),
    batch: BatchDigestConfig::default(),
    model_options: @types.ModelOptions::default(),
  }
}

///|
/// ダイジェストサービス
/// ModelOrchestrator を使ってテキストを短縮する
pub struct DigestService {
  config : DigestServiceConfig
}

///|
pub fn DigestService::new(config~ : DigestServiceConfig) -> DigestService {
  DigestService::{ config, }
}

///|
pub fn DigestService::with_defaults() -> DigestService {
  DigestService::new(config=DigestServiceConfig::default())
}

// ============================================================
// Core Digest Functions
// ============================================================

///|
/// 短縮用のシステムプロンプト
fn digest_system_prompt(context_type : DigestContextType) -> String {
  let context_desc = match context_type {
    Conversation => "会話ログ"
    Document => "ドキュメント"
    Notes => "メモ・ノート"
  }
  let template =
    #|あなたは文章短縮の専門家です。与えられた$context_desc$を、意味を完全に保持しながら冗長な表現を削除して短縮してください。
    #|
    #|## 重要なルール
    #|
    #|1. **これは要約ではなく短縮です**
    #|   - 新しい文を作らない
    #|   - 元の表現をできるだけ維持
    #|   - 削除のみで変形しない
    #|
    #|2. **保持すべきもの**
    #|   - 固有名詞（人名、プロジェクト名、技術用語）
    #|   - 数値データ
    #|   - 因果関係
    #|   - 時系列情報
    #|
    #|3. **削除すべきもの**
    #|   - 挨拶、相槌（「よろしくお願いします」「なるほど」等）
    #|   - 重複した内容
    #|   - 冗長な修飾語
    #|   - フィラー表現
    #|
    #|4. **出力形式**
    #|   - 短縮したテキストのみを出力
    #|   - 説明や前置きは不要
    #|   - マークダウンの構造は保持
  template.replace(old="$context_desc$", new=context_desc)
}

///|
/// 単一テキストを短縮（1回の呼び出し）
pub async fn digest_once(
  orchestrator : &@interfaces.ModelOrchestrator,
  text : String,
  context_type : DigestContextType,
  options : @types.ModelOptions,
) -> String raise DigestError {
  if text.is_empty() {
    raise EmptyInput
  }
  let system = digest_system_prompt(context_type)
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System(system),
    @types.ModelMessage::User(content=text, name=None),
  ]
  let response = orchestrator.call(messages~, tools=[], options~) catch {
    e => raise ModelCallError("Model call failed: \{e}")
  }
  match response {
    @types.ModelResponse::Text(result) => result
    @types.ModelResponse::ModelError(err) => raise ModelCallError(err)
    @types.ModelResponse::RateLimited(retry_after=after) =>
      raise ModelCallError("Rate limited, retry after \{after}s")
    @types.ModelResponse::ToolCalls(_) =>
      raise ModelCallError("Unexpected tool calls in digest response")
  }
}

///|
/// 反復的に短縮（収束するまで繰り返す）
pub async fn DigestService::digest_iterative(
  self : DigestService,
  orchestrator : &@interfaces.ModelOrchestrator,
  text : String,
  context_type : DigestContextType,
) -> String raise DigestError {
  if text.is_empty() {
    raise EmptyInput
  }
  let config = self.config.iterative
  let mut current = text
  let mut iteration = 0
  while iteration < config.max_iterations {
    let before_len = current.iter().count()
    let shortened = digest_once(
      orchestrator,
      current,
      context_type,
      self.config.model_options,
    ) catch {
      e => raise e
    }
    let after_len = shortened.iter().count()
    // 収束判定: 削減率が閾値以下なら停止
    let reduction = if before_len > 0 {
      (before_len - after_len).to_double() / before_len.to_double()
    } else {
      0.0
    }
    current = shortened
    iteration = iteration + 1
    // 十分短くなった、または収束した場合は停止
    if reduction < config.convergence_threshold {
      break
    }
    // 目標圧縮率に達した場合も停止
    let original_len = text.iter().count()
    let current_ratio = if original_len > 0 {
      current.iter().count().to_double() / original_len.to_double()
    } else {
      1.0
    }
    if current_ratio <= config.target_ratio {
      break
    }
  }
  current
}

///|
/// 複数テキストをバッチで短縮
/// API呼び出しを削減するため、短いテキストをまとめて処理
pub async fn DigestService::digest_batch(
  self : DigestService,
  orchestrator : &@interfaces.ModelOrchestrator,
  texts : Array[String],
  context_type : DigestContextType,
) -> Array[String] raise DigestError {
  if texts.is_empty() {
    return []
  }
  let results : Array[String] = Array::make(texts.length(), "")
  // 各テキストを個別に処理（将来的にはバッチ化を検討）
  for i = 0; i < texts.length(); i = i + 1 {
    let text = texts[i]
    if text.is_empty() {
      results[i] = ""
    } else {
      let shortened = self.digest_iterative(orchestrator, text, context_type) catch {
        e => raise e
      }
      results[i] = shortened
    }
  }
  results
}

// ============================================================
// Topic Extraction
// ============================================================

///|
/// トピック抽出用のシステムプロンプト
fn topic_extraction_prompt() -> String {
  let prompt =
    #|与えられたテキストから主要なトピック・キーワードを抽出してください。
    #|
    #|## ルール
    #|- 3〜7個のキーワードを抽出
    #|- 技術用語、固有名詞、重要な概念を優先
    #|- 一般的すぎる単語は除外（「について」「関して」等）
    #|- JSON配列形式で出力: ["keyword1", "keyword2", ...]
    #|
    #|例:
    #|入力: "MoonBitでSQLiteのFFIバインディングを実装した。エラーハンドリングにはsuberrorを使用。"
    #|出力: ["MoonBit", "SQLite", "FFI", "バインディング", "suberror", "エラーハンドリング"]
  prompt
}

///|
/// テキストからトピックキーワードを抽出
pub async fn extract_topics(
  orchestrator : &@interfaces.ModelOrchestrator,
  text : String,
  options : @types.ModelOptions,
) -> Array[String] raise DigestError {
  if text.is_empty() {
    return []
  }
  let system = topic_extraction_prompt()
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System(system),
    @types.ModelMessage::User(content=text, name=None),
  ]
  let response = orchestrator.call(messages~, tools=[], options~) catch {
    e => raise ModelCallError("Model call failed: \{e}")
  }
  let result = match response {
    @types.ModelResponse::Text(r) => r
    @types.ModelResponse::ModelError(err) => raise ModelCallError(err)
    @types.ModelResponse::RateLimited(retry_after=after) =>
      raise ModelCallError("Rate limited, retry after \{after}s")
    @types.ModelResponse::ToolCalls(_) =>
      raise ModelCallError("Unexpected tool calls in topic extraction")
  }
  // JSON配列をパース
  parse_topic_array(result)
}

///|
/// JSON配列文字列からトピック配列をパース
fn parse_topic_array(json_str : String) -> Array[String] raise DigestError {
  // 前後の空白やコードブロックを除去
  let trimmed = json_str.trim()
  let cleaned = if trimmed.has_prefix("```") {
    // ```json\n[...]\n``` 形式の場合
    let lines = trimmed.to_string().split("\n")
    let content : Array[String] = []
    let mut in_block = false
    for line in lines {
      if line.has_prefix("```") {
        in_block = not(in_block)
      } else if in_block {
        content.push(line.to_string())
      }
    }
    content.join("\n")
  } else {
    trimmed.to_string()
  }
  // JSONパース
  let json = @json.parse(cleaned) catch {
    _ => raise ParseError("Failed to parse topics JSON: \{cleaned}")
  }
  match json {
    Array(arr) =>
      arr.filter_map(fn(item) {
        match item {
          String(s) => Some(s)
          _ => None
        }
      })
    _ => raise ParseError("Expected JSON array for topics")
  }
}

// ============================================================
// High-Level API
// ============================================================

///|
/// セッション会話を短縮して短期記憶エントリを作成
pub async fn DigestService::create_short_term_entry(
  self : DigestService,
  orchestrator : &@interfaces.ModelOrchestrator,
  session_id : String,
  date : String,
  messages : Array[@types.ModelMessage],
  source_file_path : String,
  timestamp : Int64,
) -> @interfaces.ShortTermMemoryEntry raise DigestError {
  // メッセージを連結してテキスト化
  let text = messages_to_text(messages)
  if text.is_empty() {
    raise EmptyInput
  }
  // 短縮
  let digest = self.digest_iterative(
    orchestrator,
    text,
    DigestContextType::Conversation,
  ) catch {
    e => raise e
  }
  // トピック抽出
  let topics = extract_topics(orchestrator, digest, self.config.model_options) catch {
    e => raise e
  }
  // トークン推定
  let estimated_tokens = estimate_tokens(digest)
  {
    session_id,
    date,
    digest,
    topics,
    original_message_count: messages.length(),
    estimated_tokens,
    created_at: timestamp,
    source_file_path,
  }
}

///|
/// メッセージ配列をテキストに変換
fn messages_to_text(messages : Array[@types.ModelMessage]) -> String {
  let parts : Array[String] = []
  for msg in messages {
    match msg {
      @types.ModelMessage::System(_) => () // システムメッセージは除外
      @types.ModelMessage::User(content=c, ..) =>
        if not(c.is_empty()) {
          parts.push("User: \{c}")
        }
      @types.ModelMessage::Assistant(content=c, ..) =>
        if not(c.is_empty()) {
          parts.push("Assistant: \{c}")
        }
      @types.ModelMessage::ToolResult(content=c, ..) =>
        if not(c.is_empty()) {
          parts.push("Tool Result: \{c}")
        }
    }
  }
  parts.join("\n\n")
}

// ============================================================
// Internal Tests
// ============================================================

///|
test "digest_system_prompt contains context type" {
  let prompt = digest_system_prompt(DigestContextType::Conversation)
  assert_true(prompt.contains("会話ログ"))
  let doc_prompt = digest_system_prompt(DigestContextType::Document)
  assert_true(doc_prompt.contains("ドキュメント"))
  let notes_prompt = digest_system_prompt(DigestContextType::Notes)
  assert_true(notes_prompt.contains("メモ・ノート"))
}

///|
test "parse_topic_array with valid JSON" {
  let result : Result[Array[String], Error] = Ok(
    parse_topic_array("[\"a\", \"b\", \"c\"]"),
  ) catch {
    e => Err(e)
  }
  match result {
    Ok(topics) => {
      assert_eq(topics.length(), 3)
      assert_eq(topics[0], "a")
      assert_eq(topics[1], "b")
      assert_eq(topics[2], "c")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse_topic_array with code block format" {
  let result : Result[Array[String], Error] = Ok(
    parse_topic_array("```json\n[\"topic1\", \"topic2\"]\n```"),
  ) catch {
    e => Err(e)
  }
  match result {
    Ok(topics) => {
      assert_eq(topics.length(), 2)
      assert_eq(topics[0], "topic1")
      assert_eq(topics[1], "topic2")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse_topic_array with invalid JSON raises ParseError" {
  let result : Result[Array[String], Error] = Ok(parse_topic_array("not json")) catch {
    e => Err(e)
  }
  match result {
    Err(_) => assert_true(true)
    Ok(_) => assert_true(false)
  }
}

///|
test "messages_to_text formats correctly" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("system message"),
    @types.ModelMessage::User(content="Hello", name=None),
    @types.ModelMessage::Assistant(content="Hi there", tool_calls=None),
  ]
  let text = messages_to_text(messages)
  assert_true(text.contains("User: Hello"))
  assert_true(text.contains("Assistant: Hi there"))
  // システムメッセージは除外される
  assert_false(text.contains("system message"))
}

///|
test "messages_to_text skips empty content" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="", name=None),
    @types.ModelMessage::Assistant(content="response", tool_calls=None),
  ]
  let text = messages_to_text(messages)
  // 空のユーザーメッセージは除外
  assert_false(text.contains("User:"))
  assert_true(text.contains("Assistant: response"))
}

///|
test "messages_to_text includes tool results" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::ToolResult(
      tool_call_id="call_1",
      content="Result data",
    ),
  ]
  let text = messages_to_text(messages)
  assert_true(text.contains("Tool Result: Result data"))
}

///|
test "topic_extraction_prompt contains expected content" {
  let prompt = topic_extraction_prompt()
  assert_true(prompt.contains("トピック"))
  assert_true(prompt.contains("キーワード"))
  assert_true(prompt.contains("JSON配列"))
}
