///|
/// Context Pruning
/// OpenClaw-compatible context pruning strategies

///|
/// Context pruner for managing message history
pub struct ContextPruner {
  config : @types.ContextPruningConfig
}

///|
/// Create new context pruner
pub fn ContextPruner::new(config : @types.ContextPruningConfig) -> ContextPruner {
  { config, }
}

///|
/// Create context pruner with default config
pub fn ContextPruner::default() -> ContextPruner {
  { config: @types.ContextPruningConfig::default() }
}

///|
/// Prune messages based on configured strategy
pub fn ContextPruner::prune(
  self : ContextPruner,
  messages : Array[@types.ModelMessage],
) -> Array[@types.ModelMessage] {
  match self.config.strategy {
    @types.PruningStrategy::CacheTTL(ttl_ms) =>
      self.prune_by_ttl(messages, ttl_ms)
    @types.PruningStrategy::SoftTrim(max_messages) =>
      self.prune_soft_trim(messages, max_messages)
    @types.PruningStrategy::HardClear => self.prune_hard_clear(messages)
  }
}

///|
/// Prune messages based on TTL (time-to-live)
/// Note: Requires timestamp metadata in messages - currently not supported
/// Falls back to soft trim with reasonable limit
fn ContextPruner::prune_by_ttl(
  self : ContextPruner,
  messages : Array[@types.ModelMessage],
  _ttl_ms : Int64,
) -> Array[@types.ModelMessage] {
  // TTL pruning would require timestamp metadata on messages
  // For now, fall back to soft trim with a reasonable limit
  self.prune_soft_trim(messages, 50)
}

///|
/// Soft trim: keep only the last N messages
fn ContextPruner::prune_soft_trim(
  self : ContextPruner,
  messages : Array[@types.ModelMessage],
  max_messages : Int,
) -> Array[@types.ModelMessage] {
  if messages.length() <= max_messages {
    return messages
  }
  let result : Array[@types.ModelMessage] = []
  // Preserve system messages if configured
  if self.config.preserve_system {
    for msg in messages {
      match msg {
        @types.ModelMessage::System(_) => {
          result.push(msg)
        }
        _ => ()
      }
    }
  }
  // Calculate how many non-system messages we can keep
  let system_count = result.length()
  let non_system_limit = max_messages - system_count
  if non_system_limit <= 0 {
    return result
  }
  // Collect non-system messages
  let non_system : Array[@types.ModelMessage] = []
  for msg in messages {
    match msg {
      @types.ModelMessage::System(_) => ()
      _ => non_system.push(msg)
    }
  }
  // Keep only the last N non-system messages
  let start_idx = if non_system.length() > non_system_limit {
    non_system.length() - non_system_limit
  } else {
    0
  }
  for i = start_idx; i < non_system.length(); i = i + 1 {
    result.push(non_system[i])
  }
  result
}

///|
/// Hard clear: remove all messages except system prompt
fn ContextPruner::prune_hard_clear(
  self : ContextPruner,
  messages : Array[@types.ModelMessage],
) -> Array[@types.ModelMessage] {
  let result : Array[@types.ModelMessage] = []
  if self.config.preserve_system {
    for msg in messages {
      match msg {
        @types.ModelMessage::System(_) => result.push(msg)
        _ => ()
      }
    }
  }
  result
}

///|
/// Estimate token count for messages (simple heuristic)
/// Uses ~4 characters per token as approximation
pub fn estimate_token_count(messages : Array[@types.ModelMessage]) -> Int {
  let mut total_chars = 0
  for msg in messages {
    total_chars = total_chars + get_message_content_length(msg)
  }
  // Approximate 4 characters per token
  (total_chars + 3) / 4
}

///|
/// Get content length from a message
fn get_message_content_length(msg : @types.ModelMessage) -> Int {
  match msg {
    @types.ModelMessage::System(content) => content.length()
    @types.ModelMessage::User(content~, ..) => content.length()
    @types.ModelMessage::Assistant(content~, ..) => content.length()
    @types.ModelMessage::ToolResult(content~, ..) => content.length()
  }
}

///|
/// Prune messages to fit within token budget
pub fn ContextPruner::prune_to_token_budget(
  self : ContextPruner,
  messages : Array[@types.ModelMessage],
  max_tokens : Int,
) -> Array[@types.ModelMessage] {
  let min_tokens = match self.config.min_context_tokens {
    Some(n) => n
    None => 1000
  }
  let target_tokens = if max_tokens > min_tokens { max_tokens } else { min_tokens }
  let current_tokens = estimate_token_count(messages)
  if current_tokens <= target_tokens {
    return messages
  }
  // Progressively reduce message count until within budget
  let mut current_limit = messages.length()
  let mut result = messages
  while estimate_token_count(result) > target_tokens && current_limit > 1 {
    current_limit = current_limit - 1
    result = self.prune_soft_trim(messages, current_limit)
  }
  result
}
