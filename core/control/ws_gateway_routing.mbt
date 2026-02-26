///|
/// WebSocket Gateway Routing
/// Message dispatch and request handlers

///|
/// Handle incoming JSON-RPC message from WebSocket client
pub fn WsGatewayHandler::handle_message(
  self : WsGatewayHandler,
  client_id : String,
  message : String,
) -> String {
  // Parse JSON-RPC request
  let request : @interfaces.JsonRpcRequest = match
    parse_jsonrpc_request(message) {
    Some(req) => req
    None => return jsonrpc_error_response(None, -32700, "Parse error", None)
  }
  // Check if client exists
  match self.clients.get(client_id) {
    Some(client) => self.dispatch_request(client, request)
    None => jsonrpc_error_response(request.id, -32600, "Client not found", None)
  }
}

///|
/// Dispatch JSON-RPC request to appropriate handler
fn WsGatewayHandler::dispatch_request(
  self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
) -> String {
  match request.rpc_method {
    // Authentication
    "auth" => self.handle_auth(client, request)
    // Gateway methods (require auth)
    "gateway.status" =>
      self.require_auth(client, request, fn(_) {
        self.handle_gateway_status(request)
      })
    "gateway.health" =>
      self.require_auth(client, request, fn(_) {
        self.handle_gateway_health(request)
      })
    // Channel methods (require auth)
    "channel.list" =>
      self.require_auth(client, request, fn(_) {
        self.handle_channel_list(request)
      })
    "channel.connect" =>
      self.require_auth(client, request, fn(_) {
        self.handle_channel_connect(request)
      })
    "channel.disconnect" =>
      self.require_auth(client, request, fn(_) {
        self.handle_channel_disconnect(request)
      })
    // Session methods (require auth)
    "session.list" =>
      self.require_auth(client, request, fn(_) {
        self.handle_session_list(request)
      })
    "session.get" =>
      self.require_auth(client, request, fn(_) {
        self.handle_session_get(request)
      })
    // Message methods (require auth)
    "message.send" =>
      self.require_auth(client, request, fn(_) {
        self.handle_message_send(request)
      })
    // Subscription methods
    "subscribe" => self.handle_subscribe(client, request)
    "unsubscribe" => self.handle_unsubscribe(client, request)
    // Unknown method
    _ =>
      jsonrpc_error_response(
        request.id,
        -32601,
        "Method not found: \{request.rpc_method}",
        None,
      )
  }
}

///|
/// Require authentication wrapper
fn WsGatewayHandler::require_auth(
  _self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
  handler : (@interfaces.AuthContext) -> String,
) -> String {
  if not(client.authenticated) {
    return jsonrpc_error_response(request.id, -32000, "Not authenticated", None)
  }
  match client.auth_context {
    Some(ctx) => handler(ctx)
    None =>
      jsonrpc_error_response(request.id, -32000, "Invalid auth context", None)
  }
}

///|
/// Handle auth request
fn WsGatewayHandler::handle_auth(
  self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let token = match @interfaces.rpc_require_string(request, "token") {
    Ok(t) => t
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'token' parameter",
        None,
      )
  }
  let result = self.authenticate_client(client.id, token)
  match result {
    @interfaces.AuthResult::Authenticated(ctx) =>
      jsonrpc_success_response(request.id, {
        "authenticated": true,
        "token": Json::string(ctx.token),
        "user_id": match ctx.user_id {
          Some(u) => Json::string(u)
          None => Json::null()
        },
      })
    @interfaces.AuthResult::Denied(msg) =>
      jsonrpc_error_response(request.id, -32001, msg, None)
    @interfaces.AuthResult::Expired =>
      jsonrpc_error_response(request.id, -32001, "Token expired", None)
  }
}

///|
/// Handle gateway.status request
fn WsGatewayHandler::handle_gateway_status(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  match self.gateway {
    Some(gw) => {
      let status = gw.status()
      jsonrpc_success_response(request.id, {
        "state": Json::string(gateway_state_to_string(status.state)),
        "started_at": match status.started_at {
          Some(t) => Json::number(t.to_double())
          None => Json::null()
        },
        "connected_channels_count": Json::number(
          status.connected_channels.length().to_double(),
        ),
        "connected_channels": Json::array(
          status.connected_channels.map(fn(c) { Json::string(c) }),
        ),
        "active_sessions": Json::number(status.active_sessions.to_double()),
        "version": Json::string(status.version),
      })
    }
    None =>
      jsonrpc_error_response(request.id, -32002, "Gateway not configured", None)
  }
}

///|
/// Handle gateway.health request
fn WsGatewayHandler::handle_gateway_health(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  match self.gateway {
    Some(_) =>
      jsonrpc_success_response(request.id, {
        "healthy": true,
        "checks": Json::array([]),
      })
    None =>
      jsonrpc_error_response(request.id, -32002, "Gateway not configured", None)
  }
}

///|
/// Handle channel.list request
fn WsGatewayHandler::handle_channel_list(
  _self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  // Return empty list for now (would need to query Gateway's channel manager)
  jsonrpc_success_response(request.id, { "channels": Json::array([]) })
}

///|
/// Handle session.list request
fn WsGatewayHandler::handle_session_list(
  _self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  // Return empty list for now (would need to query Gateway's session store)
  jsonrpc_success_response(request.id, { "sessions": Json::array([]) })
}

///|
/// Handle channel.connect request
fn WsGatewayHandler::handle_channel_connect(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let channel_name = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'channel' parameter",
        None,
      )
  }
  // Connect channel via Gateway
  match self.gateway {
    Some(gw) =>
      // In a real implementation, this would call gw.connect_channel(channel_name)
      ignore(gw)
    None => ()
  }
  // Return success (mock implementation)
  jsonrpc_success_response(request.id, {
    "channel": Json::string(channel_name),
    "connected": true,
  })
}

///|
/// Handle channel.disconnect request
fn WsGatewayHandler::handle_channel_disconnect(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let channel_name = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'channel' parameter",
        None,
      )
  }
  // Disconnect channel via Gateway
  match self.gateway {
    Some(gw) =>
      // In a real implementation, this would call gw.disconnect_channel(channel_name)
      ignore(gw)
    None => ()
  }
  // Return success (mock implementation)
  jsonrpc_success_response(request.id, {
    "channel": Json::string(channel_name),
    "disconnected": true,
  })
}

///|
/// Handle session.get request
fn WsGatewayHandler::handle_session_get(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let session_id = match @interfaces.rpc_require_string(request, "session_id") {
    Ok(s) => s
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'session_id' parameter",
        None,
      )
  }
  // Get session from Gateway's session store
  match self.gateway {
    Some(gw) =>
      // In a real implementation, this would call gw.get_session(session_id)
      ignore(gw)
    None => ()
  }
  // Return not found (mock implementation - no sessions stored)
  jsonrpc_error_response(
    request.id,
    -32004,
    "Session not found: \{session_id}",
    None,
  )
}

///|
/// Handle message.send request
fn WsGatewayHandler::handle_message_send(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let channel = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'channel' parameter",
        None,
      )
  }
  let chat_id = match @interfaces.rpc_require_string(request, "chat_id") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'chat_id' parameter",
        None,
      )
  }
  let content = match @interfaces.rpc_require_string(request, "content") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'content' parameter",
        None,
      )
  }
  // Send message via Gateway's outbound dispatcher
  match self.gateway {
    Some(gw) =>
      // In a real implementation, this would call gw.send_message(channel, chat_id, content)
      ignore(gw)
    None => ()
  }
  // Return success (mock implementation)
  jsonrpc_success_response(request.id, {
    "sent": true,
    "channel": Json::string(channel),
    "chat_id": Json::string(chat_id),
    "content_length": Json::number(content.length().to_double()),
  })
}

///|
/// Handle subscribe request
fn WsGatewayHandler::handle_subscribe(
  self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let events = @interfaces.rpc_string_array(request, "events")
  if events.length() == 0 {
    return jsonrpc_error_response(
      request.id,
      -32602,
      "Missing 'events' parameter",
      None,
    )
  }
  for event in events {
    if not(client.subscriptions.contains(event)) {
      client.subscriptions.push(event)
    }
  }
  ignore(self)
  jsonrpc_success_response(request.id, {
    "subscribed": Json::array(
      client.subscriptions.map(fn(s) { Json::string(s) }),
    ),
  })
}

///|
/// Handle unsubscribe request
fn WsGatewayHandler::handle_unsubscribe(
  self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let events = @interfaces.rpc_string_array(request, "events")
  for event in events {
    // Remove from subscriptions
    let new_subs : Array[String] = []
    for sub in client.subscriptions {
      if sub != event {
        new_subs.push(sub)
      }
    }
    client.subscriptions.clear()
    for sub in new_subs {
      client.subscriptions.push(sub)
    }
  }
  ignore(self)
  jsonrpc_success_response(request.id, {
    "subscribed": Json::array(
      client.subscriptions.map(fn(s) { Json::string(s) }),
    ),
  })
}
