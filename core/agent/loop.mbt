///|
/// エージェントループエラー
pub(all) suberror AgentLoopError {
  MaxIterationsReached(Int)
  ModelCallFailed(String)
  ToolExecutionFailed(String)
  SessionError(String)
  ConfigurationError(String)
  RateLimitExceeded(retry_count~ : Int, last_retry_after~ : Int)
}

///|
/// リトライ設定
pub(all) struct RetryConfig {
  /// 最大リトライ回数
  max_retries : Int
  /// 初期遅延（ミリ秒）
  initial_delay_ms : Int
  /// 最大遅延（ミリ秒）
  max_delay_ms : Int
  /// バックオフ乗数
  backoff_multiplier : Double
  /// リトライ可能なエラーかどうかを判定
  retry_on_rate_limit : Bool
  /// リトライ可能なエラーコード
  retryable_status_codes : Array[Int]
}

///|
/// デフォルトのリトライ設定
pub fn RetryConfig::default() -> RetryConfig {
  {
    max_retries: 3,
    initial_delay_ms: 1000,
    max_delay_ms: 60000,
    backoff_multiplier: 2.0,
    retry_on_rate_limit: true,
    retryable_status_codes: [429, 500, 502, 503, 504],
  }
}

///|
/// リトライ状態
priv struct RetryState {
  /// 現在のリトライ回数
  mut attempt : Int
  /// 次の遅延（ミリ秒）
  mut next_delay_ms : Int
  /// 最後のretry_after値（デバッグ用）
  mut last_retry_after : Int
}

///|
/// 新しいリトライ状態を作成
fn RetryState::new(config : RetryConfig) -> RetryState {
  { attempt: 0, next_delay_ms: config.initial_delay_ms, last_retry_after: 0 }
}

///|
/// リトライ可能かどうかを判定
fn RetryState::can_retry(self : RetryState, config : RetryConfig) -> Bool {
  self.attempt < config.max_retries
}

///|
/// 次のリトライのために状態を更新
fn RetryState::increment(self : RetryState, config : RetryConfig) -> Unit {
  self.attempt = self.attempt + 1
  let next = (self.next_delay_ms.to_double() * config.backoff_multiplier).to_int()
  self.next_delay_ms = if next > config.max_delay_ms {
    config.max_delay_ms
  } else {
    next
  }
}

///|
/// retry_after値で遅延を上書き
fn RetryState::set_retry_after(self : RetryState, retry_after : Int) -> Unit {
  self.last_retry_after = retry_after
  // retry_after（秒）をミリ秒に変換し、次の遅延として使用
  let retry_ms = retry_after * 1000
  if retry_ms > self.next_delay_ms {
    self.next_delay_ms = retry_ms
  }
}

///|
/// 計算された遅延を取得（ミリ秒）
pub fn calculate_backoff_delay(
  attempt : Int,
  initial_delay_ms : Int,
  max_delay_ms : Int,
  multiplier : Double,
) -> Int {
  // 乗算でバックオフを計算（pow使用を避ける）
  let mut delay = initial_delay_ms.to_double()
  for _ in 0..<attempt {
    delay = delay * multiplier
  }
  let delay_int = delay.to_int()
  if delay_int > max_delay_ms {
    max_delay_ms
  } else {
    delay_int
  }
}

///|
/// エージェントループの実行オプション
pub(all) struct AgentLoopOptions {
  /// 最大反復回数
  max_iterations : Int
  /// モデルオプション
  model_options : @types.ModelOptions
  /// タイムアウト（ミリ秒）
  timeout_ms : Int64
  /// リトライ設定
  retry_config : RetryConfig
}

///|
/// デフォルトのエージェントループオプション
pub fn AgentLoopOptions::default() -> AgentLoopOptions {
  {
    max_iterations: 10,
    model_options: @types.ModelOptions::default(),
    timeout_ms: 120000L,
    retry_config: RetryConfig::default(),
  }
}

///|
/// エージェントループの依存関係
pub(all) struct AgentDependencies {
  session_resolver : &@interfaces.SessionResolver
  session_store : &@interfaces.SessionStore
  context_builder : &@interfaces.ContextBuilder
  model_orchestrator : &@interfaces.ModelOrchestrator
  tool_registry : &@interfaces.ToolRegistry
  outbound_dispatcher : &@interfaces.OutboundDispatcher
}

///|
/// エージェントループを実行
/// 入力メッセージを処理し、モデル呼び出しとツール実行を反復して応答を生成する
pub fn run_agent_loop(
  envelope : @types.InboundEnvelope,
  options : AgentLoopOptions,
  deps : AgentDependencies,
) -> @types.OutboundMessage raise AgentLoopError {
  // 1. セッション解決
  let session_key = deps.session_resolver.resolve(envelope)
  // 2. セッション取得または作成
  let session = try {
    match deps.session_store.get(session_key) {
      Some(s) => s
      None => @types.Session::new(session_key, envelope.timestamp)
    }
  } catch {
    e => raise AgentLoopError::SessionError(e.to_string())
  }
  // 3. ループコンテキスト初期化
  let ctx = AgentLoopContext::new()
  ctx.set_state(AgentState::Processing(envelope))
  // 4. コンテキスト構築
  let context_input : @interfaces.ContextInput = {
    session_history: session.history,
    memory_context: [],
    skills: [],
    bootstrap: "",
    current_message: envelope,
  }
  ctx.messages = deps.context_builder.build(context_input)
  // 5. ツール定義取得
  let tool_definitions = deps.tool_registry.list_definitions()
  // 6. エージェントループ
  while not(ctx.is_max_iterations(options.max_iterations)) {
    ctx.set_state(AgentState::WaitingForModel)
    ctx.increment_iteration()
    // リトライ状態を初期化
    let retry_state = RetryState::new(options.retry_config)
    // モデル呼び出し（リトライロジック付き）
    let response = call_model_with_retry(
      deps.model_orchestrator,
      ctx.messages,
      tool_definitions,
      options.model_options,
      options.retry_config,
      retry_state,
    )
    match response {
      @types.ModelResponse::Text(content) => {
        // テキスト応答 - ループ完了
        ctx.set_state(AgentState::SendingResponse)
        // セッション更新
        session.add_message(
          @types.ModelMessage::User(content=envelope.content, name=None),
        )
        session.add_message(
          @types.ModelMessage::Assistant(content~, tool_calls=None),
        )
        deps.session_store.save(session) catch {
          e => raise AgentLoopError::SessionError(e.to_string())
        }
        // 出力メッセージを構築して返す
        ctx.set_state(AgentState::Completed)
        let outbound : @types.OutboundMessage = {
          channel: envelope.channel,
          chat_id: envelope.chat_id,
          content,
          reply_to: None,
          attachments: None,
          options: None,
        }
        return outbound
      }
      @types.ModelResponse::ToolCalls(calls) => {
        // ツール呼び出し - 実行して結果を追加
        for call in calls {
          ctx.set_state(
            AgentState::ExecutingTool(tool_name=call.name, call_id=call.id),
          )
          ctx.record_tool_call(call)
          // ツール実行
          let tool_result = execute_tool_call(call, session, envelope, deps)
          // 結果をメッセージに追加
          ctx.add_message(@tool.tool_result_to_message(call.id, tool_result))
        }
        // ループ継続
        continue
      }
      @types.ModelResponse::ModelError(msg) =>
        raise AgentLoopError::ModelCallFailed(msg)
      @types.ModelResponse::RateLimited(retry_after~) =>
        // リトライが有効でリトライ上限に達した場合
        raise AgentLoopError::RateLimitExceeded(
          retry_count=retry_state.attempt,
          last_retry_after=retry_after,
        )
    }
  }
  // 最大反復回数に達した
  raise AgentLoopError::MaxIterationsReached(options.max_iterations)
}

///|
/// リトライロジック付きでモデルを呼び出す
fn call_model_with_retry(
  orchestrator : &@interfaces.ModelOrchestrator,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  options : @types.ModelOptions,
  retry_config : RetryConfig,
  retry_state : RetryState,
) -> @types.ModelResponse raise AgentLoopError {
  // リトライループ
  while true {
    let response = orchestrator.call(messages~, tools~, options~) catch {
      e => raise AgentLoopError::ModelCallFailed(e.to_string())
    }
    match response {
      @types.ModelResponse::RateLimited(retry_after~) =>
        // レート制限 - リトライ可能か確認
        if retry_config.retry_on_rate_limit &&
          retry_state.can_retry(retry_config) {
          retry_state.set_retry_after(retry_after)
          retry_state.increment(retry_config)
          // 注: 実際の遅延は非同期APIが必要
          // 現在は即座にリトライする（実運用では遅延が必要）
          continue
        } else {
          // リトライ上限に達した
          return response
        }
      @types.ModelResponse::ModelError(msg) =>
        // 一部のエラーはリトライ可能
        if is_retryable_error(msg) && retry_state.can_retry(retry_config) {
          retry_state.increment(retry_config)
          continue
        } else {
          return response
        }
      _ => return response
    }
  }
  // 到達不能
  @types.ModelResponse::ModelError("Unexpected retry loop exit")
}

///|
/// エラーメッセージがリトライ可能かどうかを判定
fn is_retryable_error(error_msg : String) -> Bool {
  let retryable_patterns = [
    "timeout", "connection reset", "connection refused", "temporary failure", "service unavailable",
    "internal server error", "bad gateway", "gateway timeout",
  ]
  let lower_msg = error_msg.to_lower()
  for pattern in retryable_patterns {
    if lower_msg.contains(pattern) {
      return true
    }
  }
  false
}

///|
/// ツール呼び出しを実行
fn execute_tool_call(
  call : @types.ToolCallRequest,
  session : @types.Session,
  envelope : @types.InboundEnvelope,
  deps : AgentDependencies,
) -> @types.ToolResult {
  let context : @types.ToolContext = { session, envelope, config: {} }
  match deps.tool_registry.get_executor(call.name) {
    Some(executor) =>
      executor.execute(tool_name=call.name, arguments=call.arguments, context~) catch {
        e => @types.ToolResult::Error(message=e.to_string())
      }
    None => @types.ToolResult::Error(message="Tool not found: \{call.name}")
  }
}

///|
/// 単一のモデル呼び出しを実行（ツール呼び出しなし）
pub fn single_model_call(
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
  model_orchestrator : &@interfaces.ModelOrchestrator,
) -> @types.ModelResponse raise AgentLoopError {
  model_orchestrator.call(messages~, tools=[], options~) catch {
    e => raise AgentLoopError::ModelCallFailed(e.to_string())
  }
}

// ============================================================================
// Async Agent Loop Implementation
// ============================================================================

///|
/// 非同期エージェントループの依存関係
pub(all) struct AsyncAgentDependencies {
  session_resolver : &@interfaces.SessionResolver
  session_store : &@interfaces.SessionStore
  context_builder : &@interfaces.ContextBuilder
  tool_registry : &@interfaces.ToolRegistry
  outbound_dispatcher : &@interfaces.OutboundDispatcher
  /// モデル呼び出し関数（async関数を受け取る）
  model_invoke : async (
    Array[@types.ModelMessage],
    Array[@types.ToolDefinition],
    @types.ModelOptions,
  ) -> @types.ModelResponse
}

///|
/// リトライ付きモデル呼び出し（async版）
/// 実際に @async.sleep() で遅延を適用する
pub async fn call_model_with_retry_async(
  model_invoke : async (
    Array[@types.ModelMessage],
    Array[@types.ToolDefinition],
    @types.ModelOptions,
  ) -> @types.ModelResponse,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  options : @types.ModelOptions,
  retry_config : RetryConfig,
) -> @types.ModelResponse raise AgentLoopError {
  let retry_state = RetryState::new(retry_config)
  // リトライループ
  while true {
    let response = model_invoke(messages, tools, options) catch {
      e => raise AgentLoopError::ModelCallFailed(e.to_string())
    }
    match response {
      @types.ModelResponse::RateLimited(retry_after~) =>
        // レート制限 - リトライ可能か確認
        if retry_config.retry_on_rate_limit &&
          retry_state.can_retry(retry_config) {
          retry_state.set_retry_after(retry_after)
          let delay_ms = retry_state.next_delay_ms
          retry_state.increment(retry_config)
          // 実際に遅延を適用
          @async.sleep(delay_ms) catch {
            e => raise AgentLoopError::ModelCallFailed("Sleep cancelled: \{e}")
          }
          continue
        } else {
          // リトライ上限に達した
          return response
        }
      @types.ModelResponse::ModelError(msg) =>
        // 一部のエラーはリトライ可能
        if is_retryable_error(msg) && retry_state.can_retry(retry_config) {
          let delay_ms = retry_state.next_delay_ms
          retry_state.increment(retry_config)
          // 実際に遅延を適用
          @async.sleep(delay_ms) catch {
            e => raise AgentLoopError::ModelCallFailed("Sleep cancelled: \{e}")
          }
          continue
        } else {
          return response
        }
      _ => return response
    }
  }
  // 到達不能
  @types.ModelResponse::ModelError("Unexpected retry loop exit")
}

///|
/// 非同期エージェントループを実行
/// 入力メッセージを処理し、モデル呼び出しとツール実行を反復して応答を生成する
pub async fn run_agent_loop_async(
  envelope : @types.InboundEnvelope,
  options : AgentLoopOptions,
  deps : AsyncAgentDependencies,
) -> @types.OutboundMessage raise AgentLoopError {
  // 1. セッション解決
  let session_key = deps.session_resolver.resolve(envelope)
  // 2. セッション取得または作成
  let session = try {
    match deps.session_store.get(session_key) {
      Some(s) => s
      None => @types.Session::new(session_key, envelope.timestamp)
    }
  } catch {
    e => raise AgentLoopError::SessionError(e.to_string())
  }
  // 3. ループコンテキスト初期化
  let ctx = AgentLoopContext::new()
  ctx.set_state(AgentState::Processing(envelope))
  // 4. コンテキスト構築
  let context_input : @interfaces.ContextInput = {
    session_history: session.history,
    memory_context: [],
    skills: [],
    bootstrap: "",
    current_message: envelope,
  }
  ctx.messages = deps.context_builder.build(context_input)
  // 5. ツール定義取得
  let tool_definitions = deps.tool_registry.list_definitions()
  // 6. 非同期エージェントループ
  while not(ctx.is_max_iterations(options.max_iterations)) {
    ctx.set_state(AgentState::WaitingForModel)
    ctx.increment_iteration()
    // モデル呼び出し（リトライロジック付き）
    let response = call_model_with_retry_async(
      deps.model_invoke,
      ctx.messages,
      tool_definitions,
      options.model_options,
      options.retry_config,
    )
    match response {
      @types.ModelResponse::Text(content) => {
        // テキスト応答 - ループ完了
        ctx.set_state(AgentState::SendingResponse)
        // セッション更新
        session.add_message(
          @types.ModelMessage::User(content=envelope.content, name=None),
        )
        session.add_message(
          @types.ModelMessage::Assistant(content~, tool_calls=None),
        )
        deps.session_store.save(session) catch {
          e => raise AgentLoopError::SessionError(e.to_string())
        }
        // 出力メッセージを構築して返す
        ctx.set_state(AgentState::Completed)
        let outbound : @types.OutboundMessage = {
          channel: envelope.channel,
          chat_id: envelope.chat_id,
          content,
          reply_to: None,
          attachments: None,
          options: None,
        }
        return outbound
      }
      @types.ModelResponse::ToolCalls(calls) => {
        // ツール呼び出し - 実行して結果を追加
        for call in calls {
          ctx.set_state(
            AgentState::ExecutingTool(tool_name=call.name, call_id=call.id),
          )
          ctx.record_tool_call(call)
          // ツール実行
          let tool_result = execute_tool_call_async(call, session, envelope, deps)
          // 結果をメッセージに追加
          ctx.add_message(@tool.tool_result_to_message(call.id, tool_result))
        }
        // ループ継続
        continue
      }
      @types.ModelResponse::ModelError(msg) =>
        raise AgentLoopError::ModelCallFailed(msg)
      @types.ModelResponse::RateLimited(retry_after~) =>
        // リトライが有効でリトライ上限に達した場合
        raise AgentLoopError::RateLimitExceeded(
          retry_count=options.retry_config.max_retries,
          last_retry_after=retry_after,
        )
    }
  }
  // 最大反復回数に達した
  raise AgentLoopError::MaxIterationsReached(options.max_iterations)
}

///|
/// ツール呼び出しを実行（async版用）
fn execute_tool_call_async(
  call : @types.ToolCallRequest,
  session : @types.Session,
  envelope : @types.InboundEnvelope,
  deps : AsyncAgentDependencies,
) -> @types.ToolResult {
  let context : @types.ToolContext = { session, envelope, config: {} }
  match deps.tool_registry.get_executor(call.name) {
    Some(executor) =>
      executor.execute(tool_name=call.name, arguments=call.arguments, context~) catch {
        e => @types.ToolResult::Error(message=e.to_string())
      }
    None => @types.ToolResult::Error(message="Tool not found: \{call.name}")
  }
}
