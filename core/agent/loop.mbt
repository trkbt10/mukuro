///|
/// エージェントループエラー
pub(all) suberror AgentLoopError {
  MaxIterationsReached(Int)
  ModelCallFailed(String)
  ToolExecutionFailed(String)
  SessionError(String)
  ConfigurationError(String)
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
}

///|
/// デフォルトのエージェントループオプション
pub fn AgentLoopOptions::default() -> AgentLoopOptions {
  {
    max_iterations: 10,
    model_options: @types.ModelOptions::default(),
    timeout_ms: 120000L,
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
    // モデル呼び出し
    let response = deps.model_orchestrator.call(
      messages=ctx.messages,
      tools=tool_definitions,
      options=options.model_options,
    ) catch {
      e => raise AgentLoopError::ModelCallFailed(e.to_string())
    }
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
        raise AgentLoopError::ModelCallFailed(
          "Rate limited, retry after \{retry_after}s",
        )
    }
  }
  // 最大反復回数に達した
  raise AgentLoopError::MaxIterationsReached(options.max_iterations)
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
