///|
/// HTTP/REST チャネル設定（native）
pub(all) struct HttpChannelConfig {
  name : String
  auth_token : String?
  webhook_url : String?
  base : ChannelBaseConfig
}

///|
pub fn HttpChannelConfig::default(name~ : String) -> HttpChannelConfig {
  {
    name,
    auth_token: None,
    webhook_url: None,
    base: ChannelBaseConfig::default(name~),
  }
}

///|
pub struct HttpChannelAdapter {
  config : HttpChannelConfig
  mut status : ChannelStatus
  received_messages : Array[@types.InboundEnvelope]
  http_client : @native.NativeHttpClient
}

///|
pub fn HttpChannelAdapter::new(
  config : HttpChannelConfig,
) -> HttpChannelAdapter {
  {
    config,
    status: ChannelStatus::Disconnected,
    received_messages: [],
    http_client: @native.NativeHttpClient::default(),
  }
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with name(self) {
  self.config.name
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with connect(self) {
  self.status = ChannelStatus::Connected
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with disconnect(self) {
  self.status = ChannelStatus::Disconnected
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with is_connected(
  self,
) {
  match self.status {
    ChannelStatus::Connected => true
    _ => false
  }
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with send(
  self,
  message,
) {
  match self.config.webhook_url {
    Some(url) => {
      let payload = outbound_to_json(message)
      let headers : Map[String, String] = { "Content-Type": "application/json" }
      match self.config.auth_token {
        Some(token) => headers["Authorization"] = "Bearer \{token}"
        None => ()
      }
      let body = Bytes::from_iter(
        payload
        .stringify()
        .iter()
        .map(fn(c) { c.to_int().land(0xFF).to_byte() }),
      )
      let _ = self.http_client.do_request({
        url,
        http_method: @interfaces.HttpMethod::Post,
        headers,
        body: Some(body),
      }) catch {
        e => raise ChannelError::NetworkError(http_error_message(e))
      }
    }
    None => ()
  }
}

///|
fn http_error_message(err : @native.HttpError) -> String {
  match err {
    @native.HttpError::ConnectionFailed(msg) => msg
    @native.HttpError::Timeout => "timeout"
    @native.HttpError::InvalidUrl(url) => "invalid url: \{url}"
    @native.HttpError::StatusError(status, msg) => "status \{status}: \{msg}"
  }
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with receive(self) {
  if self.received_messages.length() > 0 {
    let msg = self.received_messages[0]
    let new_arr : Array[@types.InboundEnvelope] = []
    for i in 1..<self.received_messages.length() {
      new_arr.push(self.received_messages[i])
    }
    self.received_messages.clear()
    for m in new_arr {
      self.received_messages.push(m)
    }
    msg
  } else {
    raise ChannelError::NetworkError("No messages in queue")
  }
}

///|
pub fn HttpChannelAdapter::handle_request(
  self : HttpChannelAdapter,
  request_body : Json,
  chat_id : String,
  sender_id : String,
) -> Unit {
  let content = match request_body {
    { "content": String(c), .. } => c
    { "message": String(m), .. } => m
    { "text": String(t), .. } => t
    _ => request_body.stringify()
  }
  let envelope : @types.InboundEnvelope = {
    channel: self.config.name,
    chat_id,
    sender_id,
    sender_name: sender_id,
    content,
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: @native.c_time() * 1000,
  }
  self.received_messages.push(envelope)
}

///|
fn outbound_to_json(message : @types.OutboundMessage) -> Json {
  {
    "channel": message.channel,
    "chat_id": message.chat_id,
    "content": message.content,
  }
}
