///|
/// WebSocket Chat Handler Stub (Non-native)
/// Stub implementation for JS/WASM targets

///|
/// Chat WebSocket message types
pub(all) enum ChatWsMessageType {
  Send
  LoadHistory
  Ping
  Unknown
} derive(Eq, Show)

///|
/// Chat WebSocket handler dependencies (stub - not used)
pub(all) struct ChatWsDeps {
  _placeholder : Unit
}

///|
/// Chat WebSocket handler (stub)
pub struct ChatWsHandler {
  _placeholder : Unit
}

///|
/// Parse incoming WebSocket message (stub)
pub fn parse_chat_ws_message(
  _text : String,
) -> (ChatWsMessageType, String?, String?) {
  (Unknown, None, None)
}
