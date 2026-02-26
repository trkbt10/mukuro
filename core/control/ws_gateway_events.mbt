///|
/// WebSocket Gateway Events
/// Event broadcasting and JSON serialization

///|
/// Broadcast event to subscribed clients
pub fn WsGatewayHandler::broadcast_event(
  self : WsGatewayHandler,
  event : GatewayEvent,
) -> Unit {
  let event_type = get_event_type(event)
  let event_json = event_to_json(event)
  // Broadcast to all subscribed clients
  for client_id, client in self.clients {
    if client.subscriptions.contains(event_type) ||
      client.subscriptions.contains("*") {
      // Add to message buffer
      match self.message_buffers.get(client_id) {
        Some(buffer) => buffer.push(event_json.stringify())
        None => ()
      }
    }
  }
}

///|
/// Get event type string
pub fn get_event_type(event : GatewayEvent) -> String {
  match event {
    StateChanged(..) => "state_changed"
    MessageReceived(..) => "message_received"
    MessageSent(..) => "message_sent"
    ChannelConnected(..) => "channel_connected"
    ChannelDisconnected(..) => "channel_disconnected"
    Error(..) => "error"
  }
}

///|
/// Convert event to JSON
pub fn event_to_json(event : GatewayEvent) -> Json {
  let obj : Map[String, Json] = { "type": Json::string(get_event_type(event)) }
  match event {
    StateChanged(old~, new~) => {
      obj["old_state"] = Json::string(gateway_state_to_string(old))
      obj["new_state"] = Json::string(gateway_state_to_string(new))
    }
    MessageReceived(envelope~) =>
      obj["envelope"] = inbound_envelope_to_json(envelope)
    MessageSent(message~) => obj["message"] = outbound_message_to_json(message)
    ChannelConnected(channel~) => obj["channel"] = Json::string(channel)
    ChannelDisconnected(channel~) => obj["channel"] = Json::string(channel)
    Error(error~) => obj["error"] = Json::string(error)
  }
  Json::object({
    "jsonrpc": "2.0",
    "method": "event",
    "params": Json::object(obj),
  })
}

///|
/// Convert InboundEnvelope to JSON
fn inbound_envelope_to_json(envelope : @types.InboundEnvelope) -> Json {
  Json::object({
    "channel": Json::string(envelope.channel),
    "chat_id": Json::string(envelope.chat_id),
    "sender_id": Json::string(envelope.sender_id),
    "sender_name": Json::string(envelope.sender_name),
    "content": Json::string(envelope.content),
    "timestamp": Json::number(envelope.timestamp.to_double()),
  })
}

///|
/// Convert OutboundMessage to JSON
fn outbound_message_to_json(message : @types.OutboundMessage) -> Json {
  let obj : Map[String, Json] = {
    "channel": Json::string(message.channel),
    "chat_id": Json::string(message.chat_id),
    "content": Json::string(message.content),
  }
  match message.reply_to {
    Some(r) => obj["reply_to"] = Json::string(r)
    None => ()
  }
  Json::object(obj)
}

///|
/// Get pending messages for client
pub fn WsGatewayHandler::get_pending_messages(
  self : WsGatewayHandler,
  client_id : String,
) -> Array[String] {
  match self.message_buffers.get(client_id) {
    Some(buffer) => {
      let messages = buffer.copy()
      buffer.clear()
      messages
    }
    None => []
  }
}
