///|
/// Gateway と AgentLoop の最小統合（全ターゲット共通）

///|
struct InMemorySessionStore {
  sessions : Map[@types.SessionKey, @types.Session]
}

///|
fn InMemorySessionStore::new() -> InMemorySessionStore {
  { sessions: {} }
}

///|
pub impl @interfaces.SessionStore for InMemorySessionStore with get(self, key) {
  self.sessions.get(key)
}

///|
pub impl @interfaces.SessionStore for InMemorySessionStore with save(
  self,
  session,
) {
  self.sessions[session.key] = session
}

///|
pub impl @interfaces.SessionStore for InMemorySessionStore with delete(
  self,
  key,
) {
  self.sessions.remove(key)
}

///|
pub impl @interfaces.SessionStore for InMemorySessionStore with list_keys(self) {
  self.sessions.keys().collect()
}

///|
struct LocalOutboundDispatcher {
  channel_manager : @channels.ChannelManagerImpl
  sent_messages : Array[@types.OutboundMessage]
}

///|
fn LocalOutboundDispatcher::new(
  channel_manager : @channels.ChannelManagerImpl,
) -> LocalOutboundDispatcher {
  { channel_manager, sent_messages: [] }
}

///|
pub impl @interfaces.OutboundDispatcher for LocalOutboundDispatcher with dispatch(
  self,
  message,
) {
  self.sent_messages.push(message)
  match self.channel_manager.get_channel(message.channel) {
    Some(channel) => channel.send(message) catch { _ => () }
    None => ()
  }
}

///|
let global_session_resolver : @session.ConfigurableSessionResolver = @session.ConfigurableSessionResolver::new(
  strategy=@session.SessionStrategy::PerAgentBinding,
)

///|
let global_session_store : InMemorySessionStore = InMemorySessionStore::new()

///|
let global_route_resolver : @channels.RouteResolver = @channels.RouteResolver::new(
  default_strategy=@session.SessionStrategy::PerAgentBinding,
)

///|
let global_channel_manager : @channels.ChannelManagerImpl = @channels.ChannelManagerImpl::new(
  router=global_route_resolver,
)

///|
let global_context_builder : @context.DefaultContextBuilder = @context.DefaultContextBuilder::default()

///|
let global_tool_registry : @tool.InMemoryToolRegistry = @tool.InMemoryToolRegistry::new()

///|
let global_outbound_dispatcher : LocalOutboundDispatcher = LocalOutboundDispatcher::new(
  global_channel_manager,
)

///|
/// グローバルClock
let global_clock : @native.NativeClock = @native.NativeClock::new()

///|
/// グローバル共有 MemoryStore（API層とエージェントループで共有）
let global_memory_store : @builtin.MemoryStore = @builtin.MemoryStore::new()

///|
/// ビルトインツール用のToolExecutorアダプタ
struct BuiltinToolExecutorAdapter {
  tool_context : @builtin.BuiltinToolContext
}

///|
pub impl @interfaces.ToolExecutor for BuiltinToolExecutorAdapter with execute(
  self,
  tool_name~,
  arguments~,
  context~,
) {
  ignore(context)
  let result = match @builtin.execute_builtin_tool(
    self.tool_context,
    tool_name,
    arguments,
  ) {
    Some(r) => r
    None =>
      match @devtools.execute_devtool(tool_name, arguments) {
        Some(r) => r
        None =>
          return @types.ToolResult::Error(
            message="Unknown tool: \{tool_name}",
          )
      }
  }
  match result.status {
    @defs.ToolResultStatus::Success =>
      @types.ToolResult::Success(content=result.data.stringify())
    @defs.ToolResultStatus::Error =>
      @types.ToolResult::Error(
        message=result.error_message.unwrap_or("Tool execution failed"),
      )
    @defs.ToolResultStatus::RequiresConfirmation =>
      @types.ToolResult::Success(content=result.data.stringify())
  }
}

///|
/// ビルトインツールをグローバルレジストリに登録
pub fn register_builtin_tools() -> Unit {
  let tool_ctx = @builtin.BuiltinToolContext::with_memory(
    global_memory_store,
    fn(msg) { global_outbound_dispatcher.sent_messages.push(msg) },
  )
  let executor : BuiltinToolExecutorAdapter = { tool_context: tool_ctx }
  for definition in @defs.get_all_tool_definitions() {
    global_tool_registry.register(definition, executor)
  }
}

///|
/// グローバル ProviderResolver
let global_provider_resolver : ConfigProviderResolver = ConfigProviderResolver::new()

///|
let global_model_orchestrator : RuntimeModelOrchestrator = RuntimeModelOrchestrator::new(
  global_provider_resolver,
)

///|
/// api_v1_settings_state から AgentLoopOptions を構築する
/// config の全値を反映し、デフォルト値との乖離を防ぐ
fn build_agent_loop_options_from_config() -> @agent.AgentLoopOptions {
  let config = match api_v1_settings_state.get_config() {
    Some(c) => c
    None => return @agent.AgentLoopOptions::default()
  }
  let defaults = @agent.AgentLoopOptions::default()
  let model_name = if config.providers.length() > 0 {
    config.providers[0].default_model
  } else {
    ""
  }
  {
    max_iterations: config.agent.max_iterations,
    model_options: {
      model_name,
      temperature: config.agent.model_options.temperature,
      max_tokens: config.agent.model_options.max_tokens,
      stop_sequences: config.agent.model_options.stop_sequences,
    },
    timeout_ms: config.agent.timeout_ms,
    retry_config: defaults.retry_config,
  }
}

///|
/// セッションごとに独立した履歴レコーダーを生成する
/// ChatWsHandler が保持し、セッションのライフサイクルを管理する
pub fn create_session_history_recorder() -> &@interfaces.HistoryRecorder {
  @native.NativeHistoryRecorder::new(base_dir=@config.data_dir())
}

///|
async fn handle_inbound_with_agent_loop(
  envelope : @types.InboundEnvelope,
  history_recorder : &@interfaces.HistoryRecorder?,
) -> @types.OutboundMessage {
  let enriched_envelope = enrich_envelope_with_workspace_context_impl(envelope)
  let options = build_agent_loop_options_from_config()
  let deps : @agent.AgentDependencies = {
    session_resolver: global_session_resolver,
    session_store: global_session_store,
    context_builder: global_context_builder,
    model_orchestrator: global_model_orchestrator,
    tool_registry: global_tool_registry,
    outbound_dispatcher: global_outbound_dispatcher,
    history_recorder,
    clock: Some(global_clock),
  }
  @agent.run_agent_loop(enriched_envelope, options, deps)
}

///|
pub async fn handle_inbound_with_agent_loop_async(
  envelope : @types.InboundEnvelope,
  history_recorder : &@interfaces.HistoryRecorder?,
) -> @types.OutboundMessage {
  let enriched_envelope = enrich_envelope_with_workspace_context_impl(envelope)
  let options = build_agent_loop_options_from_config()
  let deps : @agent.AsyncAgentDependencies = {
    session_resolver: global_session_resolver,
    session_store: global_session_store,
    context_builder: global_context_builder,
    tool_registry: global_tool_registry,
    outbound_dispatcher: global_outbound_dispatcher,
    model_invoke: async fn(messages, tools, options) {
      runtime_model_invoke_async(global_provider_resolver, messages, tools, options)
    },
    history_recorder,
    clock: Some(global_clock),
  }
  @agent.run_agent_loop_async(enriched_envelope, options, deps)
}

///|
pub fn create_global_gateway(version : String) -> @control.Gateway {
  register_builtin_tools()
  @control.Gateway::with_components(
    channel_manager=Some(global_channel_manager),
    session_resolver=Some(global_session_resolver),
    session_store=Some(global_session_store),
    health_aggregator=None,
    outbound_dispatcher=Some(global_outbound_dispatcher),
    time_provider=None,
    agent_handler=Some(
      @control.AgentHandler::new(handler=async fn(envelope) {
        handle_inbound_with_agent_loop(envelope, None)
      }),
    ),
    version~,
  )
}

///|
pub fn sent_messages_count() -> Int {
  global_outbound_dispatcher.sent_messages.length()
}

///|
pub fn sent_message_at(index : Int) -> @types.OutboundMessage? {
  if index < 0 || index >= global_outbound_dispatcher.sent_messages.length() {
    None
  } else {
    Some(global_outbound_dispatcher.sent_messages[index])
  }
}

///|
async fn drain_channel_once(
  channel : &@interfaces.ChannelAdapter,
  on_message : (@types.InboundEnvelope) -> Unit,
) -> Int {
  let mut count = 0
  let mut i = 0
  while i < 16 {
    let message = @interfaces.ChannelAdapter::receive(channel) catch {
      _ => break
    }
    on_message(message)
    count = count + 1
    i = i + 1
  }
  count
}

///|
pub async fn pump_registered_channels_once(
  on_message : (@types.InboundEnvelope) -> Unit,
) -> Int {
  let mut total = 0
  for name in @interfaces.ChannelManager::list_channels(global_channel_manager) {
    match
      @interfaces.ChannelManager::get_channel(global_channel_manager, name) {
      Some(channel) => total = total + drain_channel_once(channel, on_message)
      None => ()
    }
  }
  total
}

///|
pub async fn pump_registered_channels_to_gateway(
  gateway : @control.Gateway,
  auth : @interfaces.AuthContext,
) -> Int {
  pump_registered_channels_once(fn(envelope) {
    // Note: dispatch_inbound is async but we're in a sync callback context
    // This needs architectural review - for now we ignore errors
    ignore((gateway, auth, envelope))
  })
}

///|
pub fn registered_channel_names_for_test() -> Array[String] {
  @interfaces.ChannelManager::list_channels(global_channel_manager)
}

///|
/// Global plugin system initializer (wrapped in Ref for mutability)
let global_plugin_initializer : Ref[@plugin.PluginSystemInitializer?] = {
  val: None,
}

///|
/// Initialize the plugin system from the default plugin directory (async)
pub async fn initialize_plugin_system() -> Unit {
  initialize_plugin_system_from_dir(plugin_dir=@config.data_dir() + "/plugins")
}

///|
/// Initialize the plugin system from a custom directory (async)
pub async fn initialize_plugin_system_from_dir(plugin_dir~ : String) -> Unit {
  let initializer = @plugin.PluginSystemInitializer::new(plugin_dir~)
  initializer.initialize()
  // Register plugin tools with the global tool registry
  initializer.register_with_registry(global_tool_registry)
  global_plugin_initializer.val = Some(initializer)
}

///|
/// Get the global plugin host (if initialized)
pub fn get_plugin_host() -> @plugin.PluginHostImpl? {
  match global_plugin_initializer.val {
    Some(init) => Some(init.get_host())
    None => None
  }
}

///|
/// Get the plugin tool registry (if initialized)
pub fn get_plugin_tool_registry() -> @plugin.PluginToolRegistry? {
  match global_plugin_initializer.val {
    Some(init) => Some(init.get_tool_registry())
    None => None
  }
}

///|
/// List available plugin tools
pub fn list_plugin_tools() -> Array[@types.ToolDefinition] {
  match global_plugin_initializer.val {
    Some(init) => init.get_tool_registry().get_all_tools()
    None => []
  }
}

///|
/// Check if a tool is a plugin tool
pub fn is_plugin_tool(tool_name : String) -> Bool {
  @plugin.parse_plugin_tool_name(tool_name) is Some(_)
}
