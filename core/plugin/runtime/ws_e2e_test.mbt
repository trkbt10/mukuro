///|
/// E2E tests for WebSocket transport
/// These tests require Node.js and the ws package to be installed
/// Run the WebSocket test plugin manually before running these tests:
///   cd test-plugins/ws_test && node plugin.js
///
/// NOTE: These tests use async test for WebSocket connections.

///|
/// Async test: connect and greet via WebSocket
async test "WebSocket E2E: connect and greet" {
  let client = NativeWebSocketClient::new(url="ws://localhost:9300", headers={})
  client.connect() catch {
    WebSocketClientError::ConnectionFailed(_) => return
    e => raise e
  }
  assert_true(client.is_connected())
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="greet",
    params=Some(Json::object({ "name": "WebSocket" })),
    id=Some(1),
  )
  let response = client.send_jsonrpc_request(request) catch {
    e => {
      client.close()
      raise e
    }
  }
  assert_true(response.error is None)
  match response.result {
    Some(Object(result)) =>
      match result.get("greeting") {
        Some(String(greeting)) => assert_true(greeting.contains("WebSocket"))
        _ => {
          client.close()
          panic()
        }
      }
    _ => {
      client.close()
      panic()
    }
  }
  client.close()
}

///|
/// Async test: echo method
async test "WebSocket E2E: echo method" {
  let client = NativeWebSocketClient::new(url="ws://localhost:9300", headers={})
  client.connect() catch {
    WebSocketClientError::ConnectionFailed(_) => return
    e => raise e
  }
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="echo",
    params=Some(Json::object({ "message": "Hello via WebSocket!" })),
    id=Some(2),
  )
  let response = client.send_jsonrpc_request(request) catch {
    e => {
      client.close()
      raise e
    }
  }
  assert_true(response.error is None)
  match response.result {
    Some(Object(result)) =>
      match result.get("echoed") {
        Some(String(echoed)) => assert_eq(echoed, "Hello via WebSocket!")
        _ => {
          client.close()
          panic()
        }
      }
    _ => {
      client.close()
      panic()
    }
  }
  client.close()
}

///|
/// Async test: describe method
async test "WebSocket E2E: describe method" {
  let client = NativeWebSocketClient::new(url="ws://localhost:9300", headers={})
  client.connect() catch {
    WebSocketClientError::ConnectionFailed(_) => return
    e => raise e
  }
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="describe",
    params=None,
    id=Some(3),
  )
  let response = client.send_jsonrpc_request(request) catch {
    e => {
      client.close()
      raise e
    }
  }
  assert_true(response.error is None)
  match response.result {
    Some(Object(result)) =>
      match result.get("transport") {
        Some(String(transport)) => assert_eq(transport, "websocket")
        _ => {
          client.close()
          panic()
        }
      }
    _ => {
      client.close()
      panic()
    }
  }
  client.close()
}

///|
/// Async test: multiple requests on same connection
async test "WebSocket E2E: multiple requests" {
  let client = NativeWebSocketClient::new(url="ws://localhost:9300", headers={})
  client.connect() catch {
    WebSocketClientError::ConnectionFailed(_) => return
    e => raise e
  }
  // Send multiple requests on same connection
  for i in 1..<=3 {
    let request = @interfaces.JsonRpcRequest::new(
      rpc_method="ping",
      params=None,
      id=Some(100 + i),
    )
    let response = client.send_jsonrpc_request(request) catch {
      e => {
        client.close()
        raise e
      }
    }
    assert_true(response.error is None)
    match response.result {
      Some(Object(result)) =>
        match result.get("pong") {
          Some(True) => () // pong is true, success
          _ => {
            client.close()
            panic()
          }
        }
      _ => {
        client.close()
        panic()
      }
    }
  }
  client.close()
}
