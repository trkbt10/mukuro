///|
/// Message Tool Tests

// =============================================================================
// build_outbound_message Tests
// =============================================================================

///|
test "build_outbound_message creates message with required fields" {
  let msg = build_outbound_message("discord", "123", "Hello", None)
  assert_eq(msg.channel, "discord")
  assert_eq(msg.chat_id, "123")
  assert_eq(msg.content, "Hello")
  assert_true(msg.reply_to is None)
}

///|
test "build_outbound_message includes reply_to when provided" {
  let msg = build_outbound_message("slack", "456", "Reply", Some("msg_789"))
  assert_eq(msg.channel, "slack")
  assert_eq(msg.reply_to, Some("msg_789"))
}

// =============================================================================
// execute_message_tool Tests
// =============================================================================

///|
test "execute_message_tool send action sends message" {
  let mut sent_message : @types.OutboundMessage? = None
  let send_fn = fn(msg : @types.OutboundMessage) { sent_message = Some(msg) }
  let args : Json = {
    "action": "send",
    "channel": "test_channel",
    "chat_id": "test_chat",
    "content": "Hello world",
  }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match sent_message {
    Some(msg) => {
      assert_eq(msg.channel, "test_channel")
      assert_eq(msg.chat_id, "test_chat")
      assert_eq(msg.content, "Hello world")
    }
    None => fail("Expected message to be sent")
  }
}

///|
test "execute_message_tool send action requires channel" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let args : Json = { "action": "send", "chat_id": "123", "content": "Hi" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for missing channel")
  }
}

///|
test "execute_message_tool send action requires chat_id" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let args : Json = { "action": "send", "channel": "test", "content": "Hi" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for missing chat_id")
  }
}

///|
test "execute_message_tool send action requires content" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let args : Json = { "action": "send", "channel": "test", "chat_id": "123" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for missing content")
  }
}

///|
test "execute_message_tool reply action sends reply" {
  let mut sent_message : @types.OutboundMessage? = None
  let send_fn = fn(msg : @types.OutboundMessage) { sent_message = Some(msg) }
  let args : Json = {
    "action": "reply",
    "channel": "discord",
    "chat_id": "chat_1",
    "content": "This is a reply",
    "message_id": "original_msg_123",
  }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match sent_message {
    Some(msg) => {
      assert_eq(msg.content, "This is a reply")
      assert_eq(msg.reply_to, Some("original_msg_123"))
    }
    None => fail("Expected message to be sent")
  }
}

///|
test "execute_message_tool reply action works without message_id" {
  let mut sent_message : @types.OutboundMessage? = None
  let send_fn = fn(msg : @types.OutboundMessage) { sent_message = Some(msg) }
  let args : Json = {
    "action": "reply",
    "channel": "slack",
    "chat_id": "chat_2",
    "content": "Reply without original",
  }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match sent_message {
    Some(msg) => assert_true(msg.reply_to is None)
    None => fail("Expected message to be sent")
  }
}

///|
test "execute_message_tool edit action returns not implemented error" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let args : Json = {
    "action": "edit",
    "channel": "test",
    "message_id": "123",
    "content": "Updated",
  }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for edit action")
  }
}

///|
test "execute_message_tool delete action returns not implemented error" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let args : Json = { "action": "delete", "channel": "test", "message_id": "123" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for delete action")
  }
}

///|
test "execute_message_tool react action returns not implemented error" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let args : Json = {
    "action": "react",
    "channel": "test",
    "message_id": "123",
    "emoji": "👍",
  }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for react action")
  }
}

///|
test "execute_message_tool returns error for missing action" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let args : Json = { "channel": "test", "content": "Hi" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for missing action")
  }
}

///|
test "execute_message_tool returns error for unknown action" {
  let send_fn = fn(_msg : @types.OutboundMessage) {  }
  let args : Json = { "action": "unknown_action" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for unknown action")
  }
}

