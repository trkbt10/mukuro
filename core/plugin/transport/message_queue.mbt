///|
/// Shared message queue component for transport handlers
/// Provides common functionality for incoming message handling

///|
/// Message queue for incoming JSON-RPC requests
/// Shared component used by all transport handlers
pub struct MessageQueue {
  /// Incoming message queue
  queue : Array[@interfaces.JsonRpcRequest]
  /// Message callback
  mut callback : ((@interfaces.JsonRpcRequest) -> Unit)?
}

///|
/// Create a new empty message queue
pub fn MessageQueue::new() -> MessageQueue {
  { queue: [], callback: None }
}

///|
/// Queue an incoming message and notify callback if set
pub fn MessageQueue::push(
  self : MessageQueue,
  request : @interfaces.JsonRpcRequest,
) -> Unit {
  self.queue.push(request)
  match self.callback {
    Some(cb) => cb(request)
    None => ()
  }
}

///|
/// Try to receive the next message (non-blocking, FIFO order)
pub fn MessageQueue::pop(self : MessageQueue) -> @interfaces.JsonRpcRequest? {
  if self.queue.length() > 0 {
    Some(self.queue.remove(0))
  } else {
    None
  }
}

///|
/// Set the message callback
pub fn MessageQueue::set_callback(
  self : MessageQueue,
  callback : (@interfaces.JsonRpcRequest) -> Unit,
) -> Unit {
  self.callback = Some(callback)
}

///|
/// Clear the callback
pub fn MessageQueue::clear_callback(self : MessageQueue) -> Unit {
  self.callback = None
}

///|
/// Check if queue is empty
pub fn MessageQueue::is_empty(self : MessageQueue) -> Bool {
  self.queue.is_empty()
}

///|
/// Get queue length
pub fn MessageQueue::length(self : MessageQueue) -> Int {
  self.queue.length()
}

///|
/// Clear all messages
pub fn MessageQueue::clear(self : MessageQueue) -> Unit {
  self.queue.clear()
}
