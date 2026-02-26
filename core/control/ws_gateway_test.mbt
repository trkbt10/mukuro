///|
/// WebSocket Gateway Handler Tests

///|
async test "WsGatewayHandler::new creates empty handler" {
  let handler = WsGatewayHandler::new(None)
  inspect(handler.client_count(), content="0")
}

///|
async test "WsGatewayHandler::on_client_connect creates client" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  inspect(handler.client_count(), content="1")
  inspect(client_id.has_prefix("ws_client_"), content="true")
}

///|
async test "WsGatewayHandler::on_client_disconnect removes client" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  inspect(handler.client_count(), content="1")
  handler.on_client_disconnect(client_id)
  inspect(handler.client_count(), content="0")
}

///|
async test "WsGatewayHandler::handle_message invalid JSON" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  let response = handler.handle_message(client_id, "not valid json")
  // Should return parse error
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("error") {
        Some(Object(err)) =>
          match err.get("code") {
            Some(Number(-32700.0, ..)) => ()
            _ => fail("Expected parse error code -32700")
          }
        _ => fail("Expected error object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::handle_message unknown method" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  let request = "{\"jsonrpc\":\"2.0\",\"method\":\"unknown\",\"id\":1}"
  let response = handler.handle_message(client_id, request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("error") {
        Some(Object(err)) =>
          match err.get("code") {
            Some(Number(-32601.0, ..)) => ()
            _ => fail("Expected method not found error code -32601")
          }
        _ => fail("Expected error object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::handle_message auth without token" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  let request = "{\"jsonrpc\":\"2.0\",\"method\":\"auth\",\"params\":{},\"id\":1}"
  let response = handler.handle_message(client_id, request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("error") {
        Some(Object(err)) =>
          match err.get("code") {
            Some(Number(-32602.0, ..)) => () // Invalid params
            _ => fail("Expected invalid params error")
          }
        _ => fail("Expected error object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::handle_message gateway.status not authenticated" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  let request = "{\"jsonrpc\":\"2.0\",\"method\":\"gateway.status\",\"id\":1}"
  let response = handler.handle_message(client_id, request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("error") {
        Some(Object(err)) =>
          match err.get("message") {
            Some(String(msg)) => inspect(msg, content="Not authenticated")
            _ => fail("Expected error message")
          }
        _ => fail("Expected error object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::handle_message subscribe" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  let request =
    #|{"jsonrpc":"2.0","method":"subscribe","params":{"events":["state_changed","error"]},"id":1}
  let response = handler.handle_message(client_id, request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("result") {
        Some(Object(result)) =>
          match result.get("subscribed") {
            Some(Array(arr)) => inspect(arr.length(), content="2")
            _ => fail("Expected subscribed array")
          }
        _ => fail("Expected result object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::handle_message unsubscribe" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  // First subscribe
  let sub_request =
    #|{"jsonrpc":"2.0","method":"subscribe","params":{"events":["state_changed","error"]},"id":1}
  let _ = handler.handle_message(client_id, sub_request)
  // Then unsubscribe
  let unsub_request =
    #|{"jsonrpc":"2.0","method":"unsubscribe","params":{"events":["error"]},"id":2}
  let response = handler.handle_message(client_id, unsub_request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("result") {
        Some(Object(result)) =>
          match result.get("subscribed") {
            Some(Array(arr)) => inspect(arr.length(), content="1")
            _ => fail("Expected subscribed array")
          }
        _ => fail("Expected result object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::broadcast_event adds to client buffers" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  // Subscribe to all events
  let sub_request =
    #|{"jsonrpc":"2.0","method":"subscribe","params":{"events":["*"]},"id":1}
  let _ = handler.handle_message(client_id, sub_request)
  // Broadcast an event
  let event = GatewayEvent::ChannelConnected(channel="telegram")
  handler.broadcast_event(event)
  // Check pending messages
  let messages = handler.get_pending_messages(client_id)
  inspect(messages.length(), content="1")
}

///|
async test "WsGatewayHandler::broadcast_event respects subscriptions" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  // Subscribe only to state_changed
  let sub_request =
    #|{"jsonrpc":"2.0","method":"subscribe","params":{"events":["state_changed"]},"id":1}
  let _ = handler.handle_message(client_id, sub_request)
  // Broadcast a different event type
  let event = GatewayEvent::Error(error="test error")
  handler.broadcast_event(event)
  // Should not receive the event
  let messages = handler.get_pending_messages(client_id)
  inspect(messages.length(), content="0")
}

///|
async test "WsGatewayHandler::is_client_authenticated" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  // Not authenticated initially
  inspect(handler.is_client_authenticated(client_id), content="false")
}

///|
async test "WsClientConnection::new creates unauthenticated client" {
  let client = WsClientConnection::new("test_client", 1000L)
  inspect(client.id, content="test_client")
  inspect(client.authenticated, content="false")
  inspect(client.subscriptions.length(), content="0")
}

///|
async test "GatewayEvent event types" {
  let event1 = GatewayEvent::StateChanged(
    old=@interfaces.GatewayState::Stopped,
    new=@interfaces.GatewayState::Running,
  )
  let event2 = GatewayEvent::Error(error="test")
  let event3 = GatewayEvent::ChannelConnected(channel="slack")
  inspect(get_event_type(event1), content="state_changed")
  inspect(get_event_type(event2), content="error")
  inspect(get_event_type(event3), content="channel_connected")
}

///|
async test "event_to_json creates valid JSON" {
  let event = GatewayEvent::ChannelConnected(channel="discord")
  let json = event_to_json(event)
  match json {
    Object(obj) => {
      match obj.get("method") {
        Some(String(m)) => inspect(m, content="event")
        _ => fail("Expected method")
      }
      match obj.get("params") {
        Some(Object(params)) =>
          match params.get("type") {
            Some(String(t)) => inspect(t, content="channel_connected")
            _ => fail("Expected type")
          }
        _ => fail("Expected params")
      }
    }
    _ => fail("Expected object")
  }
}

///|
async test "jsonrpc_success_response" {
  let response = jsonrpc_success_response(Some(1), { "status": "ok" })
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON")
  }
  match parsed {
    Object(obj) => {
      match obj.get("jsonrpc") {
        Some(String(v)) => inspect(v, content="2.0")
        _ => fail("Expected jsonrpc version")
      }
      match obj.get("result") {
        Some(Object(result)) =>
          match result.get("status") {
            Some(String(s)) => inspect(s, content="ok")
            _ => fail("Expected status")
          }
        _ => fail("Expected result")
      }
      match obj.get("id") {
        Some(Number(1.0, ..)) => ()
        _ => fail("Expected id")
      }
    }
    _ => fail("Expected object")
  }
}

///|
async test "jsonrpc_error_response" {
  let response = jsonrpc_error_response(
    Some(1),
    -32600,
    "Invalid Request",
    None,
  )
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON")
  }
  match parsed {
    Object(obj) =>
      match obj.get("error") {
        Some(Object(err)) => {
          match err.get("code") {
            Some(Number(-32600.0, ..)) => ()
            _ => fail("Expected error code")
          }
          match err.get("message") {
            Some(String(m)) => inspect(m, content="Invalid Request")
            _ => fail("Expected error message")
          }
        }
        _ => fail("Expected error object")
      }
    _ => fail("Expected object")
  }
}

///|
async test "WsGatewayHandler::handle_message channel.connect" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  // Authenticate first
  let auth_request =
    #|{"jsonrpc":"2.0","method":"auth","params":{"token":"test-token"},"id":1}
  let _ = handler.handle_message(client_id, auth_request)
  // Try channel.connect
  let request =
    #|{"jsonrpc":"2.0","method":"channel.connect","params":{"channel":"telegram"},"id":2}
  let response = handler.handle_message(client_id, request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("result") {
        Some(Object(result)) =>
          match result.get("connected") {
            Some(True) => ()
            _ => fail("Expected connected: true")
          }
        _ => fail("Expected result object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::handle_message channel.disconnect" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  // Authenticate first
  let auth_request =
    #|{"jsonrpc":"2.0","method":"auth","params":{"token":"test-token"},"id":1}
  let _ = handler.handle_message(client_id, auth_request)
  // Try channel.disconnect
  let request =
    #|{"jsonrpc":"2.0","method":"channel.disconnect","params":{"channel":"slack"},"id":2}
  let response = handler.handle_message(client_id, request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("result") {
        Some(Object(result)) =>
          match result.get("disconnected") {
            Some(True) => ()
            _ => fail("Expected disconnected: true")
          }
        _ => fail("Expected result object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::handle_message session.get not found" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  // Authenticate first
  let auth_request =
    #|{"jsonrpc":"2.0","method":"auth","params":{"token":"test-token"},"id":1}
  let _ = handler.handle_message(client_id, auth_request)
  // Try session.get
  let request =
    #|{"jsonrpc":"2.0","method":"session.get","params":{"session_id":"nonexistent"},"id":2}
  let response = handler.handle_message(client_id, request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("error") {
        Some(Object(err)) =>
          match err.get("code") {
            Some(Number(-32004.0, ..)) => () // Session not found
            _ => fail("Expected session not found error code -32004")
          }
        _ => fail("Expected error object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::handle_message message.send" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  // Authenticate first
  let auth_request =
    #|{"jsonrpc":"2.0","method":"auth","params":{"token":"test-token"},"id":1}
  let _ = handler.handle_message(client_id, auth_request)
  // Try message.send
  let request =
    #|{"jsonrpc":"2.0","method":"message.send","params":{"channel":"telegram","chat_id":"123","content":"Hello!"},"id":2}
  let response = handler.handle_message(client_id, request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("result") {
        Some(Object(result)) => {
          match result.get("sent") {
            Some(True) => ()
            _ => fail("Expected sent: true")
          }
          match result.get("channel") {
            Some(String(c)) => inspect(c, content="telegram")
            _ => fail("Expected channel")
          }
        }
        _ => fail("Expected result object")
      }
    _ => fail("Expected object response")
  }
}

///|
async test "WsGatewayHandler::handle_message message.send missing params" {
  let handler = WsGatewayHandler::new(None)
  let client_id = handler.on_client_connect()
  // Authenticate first
  let auth_request =
    #|{"jsonrpc":"2.0","method":"auth","params":{"token":"test-token"},"id":1}
  let _ = handler.handle_message(client_id, auth_request)
  // Try message.send without content
  let request =
    #|{"jsonrpc":"2.0","method":"message.send","params":{"channel":"telegram","chat_id":"123"},"id":2}
  let response = handler.handle_message(client_id, request)
  let parsed : Json = @json.parse(response) catch {
    _ => fail("Expected valid JSON response")
  }
  match parsed {
    Object(obj) =>
      match obj.get("error") {
        Some(Object(err)) =>
          match err.get("code") {
            Some(Number(-32602.0, ..)) => () // Invalid params
            _ => fail("Expected invalid params error code -32602")
          }
        _ => fail("Expected error object")
      }
    _ => fail("Expected object response")
  }
}
