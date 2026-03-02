///|
/// Unit tests for MessageQueue shared component

///|
test "MessageQueue: new creates empty queue" {
  let queue = MessageQueue::new()
  assert_true(queue.is_empty())
  assert_eq(queue.length(), 0)
}

///|
test "MessageQueue: push and pop FIFO order" {
  let queue = MessageQueue::new()
  let msg1 = @interfaces.JsonRpcRequest::new(
    rpc_method="method1",
    params=None,
    id=Some(1),
  )
  let msg2 = @interfaces.JsonRpcRequest::new(
    rpc_method="method2",
    params=None,
    id=Some(2),
  )
  let msg3 = @interfaces.JsonRpcRequest::new(
    rpc_method="method3",
    params=None,
    id=Some(3),
  )
  queue.push(msg1)
  queue.push(msg2)
  queue.push(msg3)
  assert_eq(queue.length(), 3)
  assert_false(queue.is_empty())
  // Pop in FIFO order
  match queue.pop() {
    Some(r) => assert_eq(r.rpc_method, "method1")
    None => panic()
  }
  match queue.pop() {
    Some(r) => assert_eq(r.rpc_method, "method2")
    None => panic()
  }
  match queue.pop() {
    Some(r) => assert_eq(r.rpc_method, "method3")
    None => panic()
  }
  // Queue should be empty now
  assert_true(queue.is_empty())
  assert_true(queue.pop() is None)
}

///|
test "MessageQueue: callback is called on push" {
  let queue = MessageQueue::new()
  let mut callback_count = 0
  let mut last_method = ""
  queue.set_callback(fn(req) {
    callback_count = callback_count + 1
    last_method = req.rpc_method
  })
  let msg1 = @interfaces.JsonRpcRequest::new(
    rpc_method="event1",
    params=None,
    id=None,
  )
  let msg2 = @interfaces.JsonRpcRequest::new(
    rpc_method="event2",
    params=None,
    id=None,
  )
  queue.push(msg1)
  assert_eq(callback_count, 1)
  assert_eq(last_method, "event1")
  queue.push(msg2)
  assert_eq(callback_count, 2)
  assert_eq(last_method, "event2")
}

///|
test "MessageQueue: no callback when not set" {
  let queue = MessageQueue::new()
  // Should not panic
  let msg = @interfaces.JsonRpcRequest::new(
    rpc_method="test",
    params=None,
    id=None,
  )
  queue.push(msg)
  assert_eq(queue.length(), 1)
}

///|
test "MessageQueue: clear_callback stops notifications" {
  let queue = MessageQueue::new()
  let mut callback_count = 0
  queue.set_callback(fn(_req) { callback_count = callback_count + 1 })
  let msg1 = @interfaces.JsonRpcRequest::new(
    rpc_method="before",
    params=None,
    id=None,
  )
  queue.push(msg1)
  assert_eq(callback_count, 1)
  queue.clear_callback()
  let msg2 = @interfaces.JsonRpcRequest::new(
    rpc_method="after",
    params=None,
    id=None,
  )
  queue.push(msg2)
  // Callback should not have been called after clear
  assert_eq(callback_count, 1)
}

///|
test "MessageQueue: clear removes all messages" {
  let queue = MessageQueue::new()
  for i in 0..<5 {
    let msg = @interfaces.JsonRpcRequest::new(
      rpc_method="msg\{i}",
      params=None,
      id=Some(i),
    )
    queue.push(msg)
  }
  assert_eq(queue.length(), 5)
  queue.clear()
  assert_true(queue.is_empty())
  assert_eq(queue.length(), 0)
}

///|
test "MessageQueue: pop on empty returns None" {
  let queue = MessageQueue::new()
  assert_true(queue.pop() is None)
  // Also after clearing
  let msg = @interfaces.JsonRpcRequest::new(
    rpc_method="test",
    params=None,
    id=None,
  )
  queue.push(msg)
  let _ = queue.pop()
  assert_true(queue.pop() is None)
}
