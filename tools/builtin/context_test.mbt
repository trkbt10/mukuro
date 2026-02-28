///|
/// BuiltinToolContext Tests

///|
test "BuiltinToolContext::new creates context with empty stores" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let ctx = BuiltinToolContext::new(send_fn)
  // memory store should be empty
  assert_eq(ctx.memory.keys().length(), 0)
  // agent_manager should start with next_id = 1
  assert_eq(ctx.agent_manager.next_id, 1)
}

///|
test "BuiltinToolContext::with_memory uses provided memory store" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let store = MemoryStore::new()
  store.set("preset_key", { "value": "preset" })
  let ctx = BuiltinToolContext::with_memory(store, send_fn)
  // should have the preset key
  assert_true(ctx.memory.has("preset_key"))
}

///|
test "BuiltinToolContext memory and agent_manager are accessible" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let ctx = BuiltinToolContext::new(send_fn)
  // can use memory
  ctx.memory.set("key1", { "data": 123 })
  assert_true(ctx.memory.has("key1"))
  // can use agent_manager
  let id = ctx.agent_manager.generate_id()
  assert_eq(id, "agent_1")
}

///|
test "BuiltinToolContext send_message function is callable" {
  let mut message_sent = false
  let send_fn = fn(_msg : @types.OutboundMessage) { message_sent = true }
  let ctx = BuiltinToolContext::new(send_fn)
  // call send_message
  let msg = build_outbound_message("test", "123", "hello", None)
  (ctx.send_message)(msg)
  assert_true(message_sent)
}

