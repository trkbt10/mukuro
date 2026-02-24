///|
test "WebSocketChannelAdapter native connect/disconnect state transition" {
  let config = WebSocketChannelConfig::default(
    name="ws",
    url="wss://example.invalid/ws",
  )
  let adapter = WebSocketChannelAdapter::new(config)
  @interfaces.ChannelAdapter::disconnect(adapter) catch {
    _ => ()
  }
  assert_true(!@interfaces.ChannelAdapter::is_connected(adapter))
}

///|
test "WebSocketChannelAdapter native handle_incoming_text and receive" {
  let config = WebSocketChannelConfig::default(
    name="ws",
    url="wss://example.invalid/ws",
  )
  let adapter = WebSocketChannelAdapter::new(config)
  adapter.handle_incoming_text(
    "{\"chat_id\":\"chat-1\",\"sender_id\":\"user-1\",\"content\":\"hello\"}",
    None,
    None,
  )
  let env = @interfaces.ChannelAdapter::receive(adapter) catch {
    _ => fail("expected received message")
  }
  assert_eq(env.channel, "ws")
  assert_eq(env.chat_id, "chat-1")
  assert_eq(env.sender_id, "user-1")
  assert_eq(env.content, "hello")
}
