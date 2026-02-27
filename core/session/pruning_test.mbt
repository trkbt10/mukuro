///|
test "ContextPruner::prune_soft_trim keeps last N messages" {
  let pruner = ContextPruner::new({
    strategy: @types.PruningStrategy::SoftTrim(3),
    preserve_system: true,
    min_context_tokens: None,
  })
  let messages = [
    @types.ModelMessage::System("You are helpful."),
    @types.ModelMessage::User(content="Message 1", name=None),
    @types.ModelMessage::Assistant(content="Response 1", tool_calls=None),
    @types.ModelMessage::User(content="Message 2", name=None),
    @types.ModelMessage::Assistant(content="Response 2", tool_calls=None),
    @types.ModelMessage::User(content="Message 3", name=None),
  ]
  let pruned = pruner.prune(messages)
  // System message + last 2 non-system messages (max 3, minus 1 system)
  inspect(pruned.length(), content="3")
}

///|
test "ContextPruner::prune preserves system messages" {
  let pruner = ContextPruner::new({
    strategy: @types.PruningStrategy::SoftTrim(2),
    preserve_system: true,
    min_context_tokens: None,
  })
  let messages = [
    @types.ModelMessage::System("System prompt"),
    @types.ModelMessage::User(content="User 1", name=None),
    @types.ModelMessage::User(content="User 2", name=None),
  ]
  let pruned = pruner.prune(messages)
  // System message should be preserved
  match pruned[0] {
    @types.ModelMessage::System(content) =>
      inspect(content, content="System prompt")
    _ => fail("Expected system message")
  }
}

///|
test "ContextPruner::prune_hard_clear removes all except system" {
  let pruner = ContextPruner::new({
    strategy: @types.PruningStrategy::HardClear,
    preserve_system: true,
    min_context_tokens: None,
  })
  let messages = [
    @types.ModelMessage::System("System"),
    @types.ModelMessage::User(content="User", name=None),
    @types.ModelMessage::Assistant(content="Assistant", tool_calls=None),
  ]
  let pruned = pruner.prune(messages)
  // Only system message should remain
  inspect(pruned.length(), content="1")
}

///|
test "estimate_token_count returns reasonable estimate" {
  let messages = [
    @types.ModelMessage::User(content="Hello world", name=None), // 11 chars
  ]
  let count = estimate_token_count(messages)
  // ~11/4 = ~3 tokens
  inspect(count >= 2 && count <= 4, content="true")
}

///|
test "ContextPruner::default creates with default config" {
  let pruner = ContextPruner::default()
  // Default strategy is SoftTrim(100)
  match pruner.config.strategy {
    @types.PruningStrategy::SoftTrim(n) => inspect(n, content="100")
    _ => fail("Expected SoftTrim")
  }
  inspect(pruner.config.preserve_system, content="true")
}
