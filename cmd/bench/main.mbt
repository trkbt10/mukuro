///|
/// run_agent_loop ベンチマーク（native専用）

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
struct NullOutboundDispatcher {
  _placeholder : Unit
}

///|
fn NullOutboundDispatcher::new() -> NullOutboundDispatcher {
  { _placeholder: () }
}

///|
pub impl @interfaces.OutboundDispatcher for NullOutboundDispatcher with dispatch(
  self,
  _message,
) {
  ignore(self)
}

///|
struct FixedTextModelOrchestrator {
  response : String
}

///|
fn FixedTextModelOrchestrator::new(
  response : String,
) -> FixedTextModelOrchestrator {
  { response, }
}

///|
pub impl @interfaces.ModelOrchestrator for FixedTextModelOrchestrator with call(
  self,
  messages~,
  tools~,
  options~,
) {
  ignore(messages)
  ignore(tools)
  ignore(options)
  @llm_types.ModelResponse::Text(self.response)
}

///|
enum SessionMode {
  Isolated
  Single
}

///|
struct BenchOptions {
  iterations : Int
  warmup : Int
  mode : SessionMode
  rich_metadata : Bool
  content_size : Int
}

///|
fn BenchOptions::default() -> BenchOptions {
  {
    iterations: 20000,
    warmup: 1000,
    mode: SessionMode::Isolated,
    rich_metadata: false,
    content_size: 64,
  }
}

///|
fn parse_int_or(default_value : Int, value : String?) -> Int {
  match value {
    Some(v) => {
      let parsed = @json.parse(v) catch { _ => Json::null() }
      match parsed {
        Number(n, ..) => n.to_int()
        _ => default_value
      }
    }
    None => default_value
  }
}

///|
fn parse_mode_or(default_value : SessionMode, value : String?) -> SessionMode {
  match value {
    Some(v) =>
      if v == "single" {
        SessionMode::Single
      } else if v == "isolated" {
        SessionMode::Isolated
      } else {
        default_value
      }
    None => default_value
  }
}

///|
fn parse_bool_or(default_value : Bool, value : String?) -> Bool {
  match value {
    Some(v) =>
      if v == "1" || v == "true" || v == "yes" {
        true
      } else if v == "0" || v == "false" || v == "no" {
        false
      } else {
        default_value
      }
    None => default_value
  }
}

///|
fn get_arg_value(args : Array[String], key : String) -> String? {
  let mut i = 0
  while i < args.length() {
    if args[i] == key {
      if i + 1 < args.length() {
        return Some(args[i + 1])
      }
      return None
    }
    i = i + 1
  }
  None
}

///|
fn parse_args() -> BenchOptions {
  let raw_args = @env.args()
  let args : Array[String] = []
  for i in 1..<raw_args.length() {
    args.push(raw_args[i])
  }
  let defaults = BenchOptions::default()
  {
    iterations: parse_int_or(
      defaults.iterations,
      get_arg_value(args, "--iterations"),
    ),
    warmup: parse_int_or(defaults.warmup, get_arg_value(args, "--warmup")),
    mode: parse_mode_or(defaults.mode, get_arg_value(args, "--mode")),
    rich_metadata: parse_bool_or(
      defaults.rich_metadata,
      get_arg_value(args, "--rich-metadata"),
    ),
    content_size: parse_int_or(
      defaults.content_size,
      get_arg_value(args, "--content-size"),
    ),
  }
}

///|
fn build_content(size : Int) -> String {
  if size <= 0 {
    return "x"
  }
  let b = StringBuilder::new()
  for _ in 0..<size {
    b.write_string("x")
  }
  b.to_string()
}

///|
fn build_metadata(rich_metadata : Bool) -> Map[String, Json] {
  if not(rich_metadata) {
    return {}
  }
  {
    "bootstrap": "You are a concise benchmark assistant.",
    "memory_context": Json::array([
      Json::string("user likes tea"),
      Json::string("prefer short responses"),
      Json::string("timezone=Asia/Tokyo"),
    ]),
    "skills": Json::array([
      Json::object({
        "name": "benchmark",
        "description": "collect timing",
        "instructions": "minimize overhead",
      }),
      Json::object({
        "name": "analysis",
        "description": "identify bottlenecks",
        "instructions": "focus on deterministic metrics",
      }),
    ]),
  }
}

///|
fn build_envelope(
  idx : Int,
  mode : SessionMode,
  content : String,
  metadata : Map[String, Json],
) -> @types.InboundEnvelope {
  let chat_id = match mode {
    SessionMode::Single => "bench-single"
    SessionMode::Isolated => "bench-\{idx}"
  }
  {
    channel: "bench",
    chat_id,
    sender_id: "bench-user",
    sender_name: "Bench User",
    content,
    message_type: @types.MessageType::Text,
    metadata,
    timestamp: idx.to_int64(),
  }
}

///|
async fn run_once(
  deps : @agent.AgentDependencies,
  options : @agent.AgentLoopOptions,
  mode : SessionMode,
  rich_metadata : Bool,
  iterations : Int,
  content_size : Int,
) -> (Int, Int) {
  let content = build_content(content_size)
  let metadata = build_metadata(rich_metadata)
  let mut done = 0
  let mut failed = 0
  for i in 0..<iterations {
    let envelope = build_envelope(i, mode, content, metadata)
    ignore(@agent.run_agent_loop(envelope, options, deps)) catch {
      _ => failed = failed + 1
    }
    done = done + 1
  }
  (done, failed)
}

///|
fn mode_to_string(mode : SessionMode) -> String {
  match mode {
    SessionMode::Isolated => "isolated"
    SessionMode::Single => "single"
  }
}

///|
async fn main {
  let bench_opts = parse_args()
  let session_resolver = @session.ConfigurableSessionResolver::default()
  let session_store = InMemorySessionStore::new()
  let context_builder = @context.DefaultContextBuilder::default()
  let model_orchestrator = FixedTextModelOrchestrator::new("ok")
  let tool_registry = @tool.InMemoryToolRegistry::new()
  let outbound_dispatcher = NullOutboundDispatcher::new()

  let deps : @agent.AgentDependencies = {
    session_resolver,
    session_store,
    context_builder,
    model_orchestrator,
    tool_registry,
    outbound_dispatcher,
    history_recorder: None,
    clock: None,
    session_manager: None,
    on_stream_event: None,
  }
  let options = @agent.AgentLoopOptions::default()

  let (warmup_done, warmup_failed) = run_once(
    deps,
    options,
    bench_opts.mode,
    bench_opts.rich_metadata,
    bench_opts.warmup,
    bench_opts.content_size,
  )
  let (iter_done, iter_failed) = run_once(
    deps,
    options,
    bench_opts.mode,
    bench_opts.rich_metadata,
    bench_opts.iterations,
    bench_opts.content_size,
  )

  println(
    "bench_run_agent_loop mode=\{mode_to_string(bench_opts.mode)} rich_metadata=\{bench_opts.rich_metadata} warmup=\{warmup_done} warmup_failed=\{warmup_failed} iterations=\{iter_done} iter_failed=\{iter_failed} content_size=\{bench_opts.content_size}",
  )
}
