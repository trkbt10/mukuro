///|
struct QueueChannel {
  name : String
  queue : Array[@types.InboundEnvelope]
}

///|
fn QueueChannel::new(name : String) -> QueueChannel {
  { name, queue: [] }
}

///|
pub impl @interfaces.ChannelAdapter for QueueChannel with name(self) {
  self.name
}

///|
pub impl @interfaces.ChannelAdapter for QueueChannel with connect(self) {
  ignore(self)
}

///|
pub impl @interfaces.ChannelAdapter for QueueChannel with disconnect(self) {
  ignore(self)
}

///|
pub impl @interfaces.ChannelAdapter for QueueChannel with is_connected(self) {
  ignore(self)
  true
}

///|
pub impl @interfaces.ChannelAdapter for QueueChannel with send(self, message) {
  ignore(self)
  ignore(message)
}

///|
pub impl @interfaces.ChannelAdapter for QueueChannel with receive(self) {
  if self.queue.length() == 0 {
    raise @channels.ChannelError::NetworkError("no message")
  }
  let msg = self.queue[0]
  let rest : Array[@types.InboundEnvelope] = []
  for i in 1..<self.queue.length() {
    rest.push(self.queue[i])
  }
  self.queue.clear()
  for m in rest {
    self.queue.push(m)
  }
  msg
}

///|
async test "pump_registered_channels_once drains queue channels" {
  let ch = QueueChannel::new("pump-test")
  ch.queue.push({
    channel: ch.name,
    chat_id: "chat-1",
    sender_id: "user-1",
    sender_name: "User",
    content: "hello from queue",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 1L,
  })
  @interfaces.ChannelManager::register(global_channel_manager, ch)
  let messages : Array[@types.InboundEnvelope] = []
  let count = pump_registered_channels_once(fn(env) { messages.push(env) })
  assert_true(count >= 1)
  assert_true(messages.length() >= 1)
}
