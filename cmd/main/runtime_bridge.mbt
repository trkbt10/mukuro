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
/// 履歴レコーダー（初期値None、create_global_gatewayで初期化）
let global_history_recorder : Ref[&@interfaces.HistoryRecorder?] = Ref::new(
  None,
)

///|
/// グローバルClock
let global_clock : @native.NativeClock = @native.NativeClock::new()

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
  match @builtin.execute_sync_tool(self.tool_context, tool_name, arguments) {
    Some(result) =>
      match result.status {
        @builtin.ToolResultStatus::Success =>
          @types.ToolResult::Success(content=result.data.stringify())
        @builtin.ToolResultStatus::Error =>
          @types.ToolResult::Error(
            message=result.error_message.unwrap_or("Tool execution failed"),
          )
        @builtin.ToolResultStatus::RequiresConfirmation =>
          @types.ToolResult::Success(content=result.data.stringify())
      }
    None =>
      @types.ToolResult::Error(message="Unknown builtin tool: \{tool_name}")
  }
}

///|
/// ビルトインツールをグローバルレジストリに登録
pub fn register_builtin_tools() -> Unit {
  let tool_ctx = @builtin.BuiltinToolContext::new(fn(msg) {
    global_outbound_dispatcher.sent_messages.push(msg)
  })
  let executor : BuiltinToolExecutorAdapter = { tool_context: tool_ctx }
  for definition in @builtin.get_all_tool_definitions() {
    global_tool_registry.register(definition, executor)
  }
}

///|
let global_model_orchestrator : RuntimeModelOrchestrator = RuntimeModelOrchestrator::default()

///|
async fn handle_inbound_with_agent_loop(
  envelope : @types.InboundEnvelope,
) -> @types.OutboundMessage {
  let enriched_envelope = enrich_envelope_with_workspace_context_impl(envelope)
  let options = @agent.AgentLoopOptions::default()
  let deps : @agent.AgentDependencies = {
    session_resolver: global_session_resolver,
    session_store: global_session_store,
    context_builder: global_context_builder,
    model_orchestrator: global_model_orchestrator,
    tool_registry: global_tool_registry,
    outbound_dispatcher: global_outbound_dispatcher,
    history_recorder: global_history_recorder.val,
    clock: Some(global_clock),
  }
  @agent.run_agent_loop(enriched_envelope, options, deps)
}

///|
pub async fn handle_inbound_with_agent_loop_async(
  envelope : @types.InboundEnvelope,
) -> @types.OutboundMessage {
  let enriched_envelope = enrich_envelope_with_workspace_context_impl(envelope)
  let options = @agent.AgentLoopOptions::default()
  let deps : @agent.AsyncAgentDependencies = {
    session_resolver: global_session_resolver,
    session_store: global_session_store,
    context_builder: global_context_builder,
    tool_registry: global_tool_registry,
    outbound_dispatcher: global_outbound_dispatcher,
    model_invoke: runtime_model_invoke_async,
    history_recorder: global_history_recorder.val,
    clock: Some(global_clock),
  }
  @agent.run_agent_loop_async(enriched_envelope, options, deps)
}

///|
pub fn create_global_gateway(version : String) -> @control.Gateway {
  register_builtin_tools()
  // 履歴レコーダーを初期化
  let recorder = @native.NativeHistoryRecorder::new(base_dir=@config.data_dir())
  global_history_recorder.val = Some(recorder)
  @control.Gateway::with_components(
    channel_manager=Some(global_channel_manager),
    session_resolver=Some(global_session_resolver),
    session_store=Some(global_session_store),
    health_aggregator=None,
    outbound_dispatcher=Some(global_outbound_dispatcher),
    time_provider=None,
    agent_handler=Some(
      @control.AgentHandler::new(handler=handle_inbound_with_agent_loop),
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
  initialize_plugin_system_from_dir(plugin_dir=".mukuro/plugins")
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
