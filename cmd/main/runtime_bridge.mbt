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
let global_session_resolver : @session.ConfigurableSessionResolver = @session.ConfigurableSessionResolver::default()

///|
let global_session_store : InMemorySessionStore = InMemorySessionStore::new()

///|
let global_route_resolver : @channels.RouteResolver = @channels.RouteResolver::new(
  default_strategy=@session.SessionStrategy::PerChat,
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
let global_model_orchestrator : RuntimeModelOrchestrator = RuntimeModelOrchestrator::default()

///|
fn handle_inbound_with_agent_loop(
  envelope : @types.InboundEnvelope,
) -> @types.OutboundMessage raise {
  let options = @agent.AgentLoopOptions::default()
  let deps : @agent.AgentDependencies = {
    session_resolver: global_session_resolver,
    session_store: global_session_store,
    context_builder: global_context_builder,
    model_orchestrator: global_model_orchestrator,
    tool_registry: global_tool_registry,
    outbound_dispatcher: global_outbound_dispatcher,
  }
  @agent.run_agent_loop(envelope, options, deps)
}

///|
pub fn create_global_gateway(version : String) -> @control.Gateway {
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
