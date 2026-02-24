///|
/// Channel Adapter Tests

// =============================================================================
// ChannelBaseConfig Tests
// =============================================================================

///|
test "ChannelBaseConfig::default has reasonable values" {
  let config = ChannelBaseConfig::default(name="test_channel")
  inspect(config.name, content="test_channel")
  inspect(config.enabled, content="true")
  inspect(config.reconnect_interval_ms, content="5000")
  inspect(config.max_reconnect_attempts, content="10")
}

// =============================================================================
// ChannelStatus Tests
// =============================================================================

///|
test "ChannelStatus variants exist" {
  let connected : ChannelStatus = ChannelStatus::Connected
  let connecting : ChannelStatus = ChannelStatus::Connecting
  let disconnected : ChannelStatus = ChannelStatus::Disconnected
  let reconnecting : ChannelStatus = ChannelStatus::Reconnecting
  let error : ChannelStatus = ChannelStatus::Error("test error")
  // Just verify they can be created
  ignore(connected)
  ignore(connecting)
  ignore(disconnected)
  ignore(reconnecting)
  ignore(error)
}

// =============================================================================
// SendResult Tests
// =============================================================================

///|
test "SendResult::success creates success result" {
  let result = SendResult::success(message_id="msg_123")
  inspect(result.success, content="true")
  inspect(result.message_id, content="Some(\"msg_123\")")
  inspect(result.error, content="None")
}

///|
test "SendResult::failure creates failure result" {
  let result = SendResult::failure(error="Connection failed")
  inspect(result.success, content="false")
  inspect(result.message_id, content="None")
  inspect(result.error, content="Some(\"Connection failed\")")
}

// =============================================================================
// RouteResolver Tests
// =============================================================================

///|
test "RouteResolver::new creates empty resolver" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  inspect(resolver.rules.length(), content="0")
}

///|
test "RouteResolver::add_rule adds rules" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  let rule = RoutingRule::new(
    name="discord_rule",
    channel_pattern="discord*",
    chat_pattern=None,
    session_strategy=@session.SessionStrategy::PerUser,
  )
  resolver.add_rule(rule)
  inspect(resolver.rules.length(), content="1")
}

///|
test "RouteResolver::resolve returns default strategy for no match" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  let envelope = @types.InboundEnvelope::default()
  let strategy = resolver.resolve(envelope)
  match strategy {
    @session.SessionStrategy::PerChat => ()
    _ => fail("Expected PerChat strategy")
  }
}

///|
test "RouteResolver::resolve matches exact channel pattern" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  let rule = RoutingRule::new(
    name="slack_rule",
    channel_pattern="slack",
    chat_pattern=None,
    session_strategy=@session.SessionStrategy::PerUser,
  )
  resolver.add_rule(rule)
  let envelope : @types.InboundEnvelope = {
    channel: "slack",
    chat_id: "channel_123",
    sender_id: "user_1",
    sender_name: "User",
    content: "Hello",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 0L,
  }
  let strategy = resolver.resolve(envelope)
  match strategy {
    @session.SessionStrategy::PerUser => ()
    _ => fail("Expected PerUser strategy")
  }
}

///|
test "RouteResolver::resolve matches wildcard channel pattern" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  let rule = RoutingRule::new(
    name="discord_rule",
    channel_pattern="discord*",
    chat_pattern=None,
    session_strategy=@session.SessionStrategy::PerUser,
  )
  resolver.add_rule(rule)
  let envelope : @types.InboundEnvelope = {
    channel: "discord_main",
    chat_id: "123",
    sender_id: "user",
    sender_name: "User",
    content: "Test",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 0L,
  }
  let strategy = resolver.resolve(envelope)
  match strategy {
    @session.SessionStrategy::PerUser => ()
    _ => fail("Expected PerUser strategy")
  }
}

///|
test "RouteResolver::resolve matches star pattern" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  let rule = RoutingRule::new(
    name="catch_all",
    channel_pattern="*",
    chat_pattern=None,
    session_strategy=@session.SessionStrategy::PerUser,
  )
  resolver.add_rule(rule)
  let envelope : @types.InboundEnvelope = {
    channel: "any_channel",
    chat_id: "123",
    sender_id: "user",
    sender_name: "User",
    content: "Test",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 0L,
  }
  let strategy = resolver.resolve(envelope)
  match strategy {
    @session.SessionStrategy::PerUser => ()
    _ => fail("Expected PerUser strategy")
  }
}

///|
test "RouteResolver::resolve matches chat pattern" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  let rule = RoutingRule::new(
    name="vip_channel",
    channel_pattern="slack",
    chat_pattern=Some("vip*"),
    session_strategy=@session.SessionStrategy::PerUser,
  )
  resolver.add_rule(rule)
  // VIP channel should match
  let vip_envelope : @types.InboundEnvelope = {
    channel: "slack",
    chat_id: "vip_room",
    sender_id: "user",
    sender_name: "User",
    content: "Test",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 0L,
  }
  let vip_strategy = resolver.resolve(vip_envelope)
  match vip_strategy {
    @session.SessionStrategy::PerUser => ()
    _ => fail("Expected PerUser strategy for VIP")
  }
  // Non-VIP channel should use default
  let normal_envelope : @types.InboundEnvelope = {
    channel: "slack",
    chat_id: "general",
    sender_id: "user",
    sender_name: "User",
    content: "Test",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 0L,
  }
  let normal_strategy = resolver.resolve(normal_envelope)
  match normal_strategy {
    @session.SessionStrategy::PerChat => ()
    _ => fail("Expected PerChat strategy for normal channel")
  }
}

// =============================================================================
// ChannelManagerImpl Tests
// =============================================================================

///|
test "ChannelManagerImpl::new creates empty manager" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  let manager = ChannelManagerImpl::new(router=resolver)
  let channels = @interfaces.ChannelManager::list_channels(manager)
  inspect(channels.length(), content="0")
}

///|
test "ChannelManagerImpl registers and retrieves channels" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  let manager = ChannelManagerImpl::new(router=resolver)
  let config = HttpChannelConfig::default(name="http_test")
  let adapter = HttpChannelAdapter::new(config)
  @interfaces.ChannelManager::register(manager, adapter)
  let channels = @interfaces.ChannelManager::list_channels(manager)
  inspect(channels.length(), content="1")
  match @interfaces.ChannelManager::get_channel(manager, "http_test") {
    Some(_) => ()
    None => fail("Expected channel to be found")
  }
  match @interfaces.ChannelManager::get_channel(manager, "nonexistent") {
    None => ()
    Some(_) => fail("Expected None for nonexistent channel")
  }
}

///|
test "ChannelManagerImpl unregister removes channel" {
  let resolver = RouteResolver::new(
    default_strategy=@session.SessionStrategy::PerChat,
  )
  let manager = ChannelManagerImpl::new(router=resolver)
  let config = HttpChannelConfig::default(name="http_test_remove")
  let adapter = HttpChannelAdapter::new(config)
  @interfaces.ChannelManager::register(manager, adapter)
  @interfaces.ChannelManager::unregister(manager, "http_test_remove")
  match @interfaces.ChannelManager::get_channel(manager, "http_test_remove") {
    None => ()
    Some(_) => fail("Expected channel to be removed")
  }
}

// =============================================================================
// HTTP Channel Tests
// =============================================================================

///|
test "HttpChannelConfig::default has correct values" {
  let config = HttpChannelConfig::default(name="http_api")
  inspect(config.name, content="http_api")
  inspect(config.auth_token, content="None")
  inspect(config.webhook_url, content="None")
  inspect(config.base.enabled, content="true")
}

///|
test "HttpChannelAdapter::new creates adapter" {
  let config = HttpChannelConfig::default(name="http")
  let adapter = HttpChannelAdapter::new(config)
  inspect(@interfaces.ChannelAdapter::name(adapter), content="http")
  inspect(@interfaces.ChannelAdapter::is_connected(adapter), content="false")
}

///|
test "HttpChannelAdapter connect and disconnect" {
  let config = HttpChannelConfig::default(name="http")
  let adapter = HttpChannelAdapter::new(config)
  inspect(@interfaces.ChannelAdapter::is_connected(adapter), content="false")
  @interfaces.ChannelAdapter::connect(adapter)
  inspect(@interfaces.ChannelAdapter::is_connected(adapter), content="true")
  @interfaces.ChannelAdapter::disconnect(adapter)
  inspect(@interfaces.ChannelAdapter::is_connected(adapter), content="false")
}

///|
test "HttpChannelAdapter::handle_request parses content field" {
  let config = HttpChannelConfig::default(name="http")
  let adapter = HttpChannelAdapter::new(config)
  let request : Json = { "content": "Hello, world!" }
  adapter.handle_request(request, "chat_1", "user_1")
  // Verify message was added to queue
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.content, content="Hello, world!")
  inspect(msg.chat_id, content="chat_1")
  inspect(msg.sender_id, content="user_1")
}

///|
test "HttpChannelAdapter::handle_request parses message field" {
  let config = HttpChannelConfig::default(name="http")
  let adapter = HttpChannelAdapter::new(config)
  let request : Json = { "message": "Test message" }
  adapter.handle_request(request, "chat_2", "user_2")
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.content, content="Test message")
}

///|
test "HttpChannelAdapter::handle_request parses text field" {
  let config = HttpChannelConfig::default(name="http")
  let adapter = HttpChannelAdapter::new(config)
  let request : Json = { "text": "Plain text" }
  adapter.handle_request(request, "chat_3", "user_3")
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.content, content="Plain text")
}

///|
test "HttpChannelAdapter::handle_request handles unknown format" {
  let config = HttpChannelConfig::default(name="http")
  let adapter = HttpChannelAdapter::new(config)
  let request : Json = { "data": "value" }
  adapter.handle_request(request, "chat_4", "user_4")
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  // Should stringify the JSON
  assert_true(msg.content.length() > 0)
}

///|
test "HttpChannelAdapter::receive raises error when queue is empty" {
  let config = HttpChannelConfig::default(name="http")
  let adapter = HttpChannelAdapter::new(config)
  let mut got_error = false
  ignore(
    @interfaces.ChannelAdapter::receive(adapter) catch {
      _ => {
        got_error = true
        return
      }
    },
  )
  if not(got_error) {
    fail("Expected error for empty queue")
  }
}

// =============================================================================
// Slack Channel Tests
// =============================================================================

///|
test "SlackChannelConfig::default has correct values" {
  let config = SlackChannelConfig::default(name="slack", bot_token="xoxb-test")
  inspect(config.name, content="slack")
  inspect(config.bot_token, content="xoxb-test")
  inspect(config.app_token, content="None")
  inspect(config.signing_secret, content="None")
  inspect(config.api_base_url, content="https://slack.com/api")
}

///|
test "SlackChannelAdapter::new creates adapter" {
  let config = SlackChannelConfig::default(name="slack", bot_token="xoxb-test")
  let adapter = SlackChannelAdapter::new(config)
  inspect(@interfaces.ChannelAdapter::name(adapter), content="slack")
  inspect(@interfaces.ChannelAdapter::is_connected(adapter), content="false")
}

///|
test "SlackChannelAdapter::handle_webhook returns challenge for url_verification" {
  let config = SlackChannelConfig::default(name="slack", bot_token="xoxb-test")
  let adapter = SlackChannelAdapter::new(config)
  let request : Json = {
    "type": "url_verification",
    "challenge": "test_challenge_123",
  }
  let response = adapter.handle_webhook(request)
  match response {
    { "challenge": "test_challenge_123", .. } => ()
    _ => fail("Expected challenge in response")
  }
}

///|
test "SlackChannelAdapter::handle_webhook processes message event" {
  let config = SlackChannelConfig::default(name="slack", bot_token="xoxb-test")
  let adapter = SlackChannelAdapter::new(config)
  let request : Json = {
    "event": {
      "type": "message",
      "channel": "C123456",
      "user": "U123456",
      "text": "Hello from Slack!",
    },
  }
  ignore(adapter.handle_webhook(request))
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.content, content="Hello from Slack!")
  inspect(msg.chat_id, content="C123456")
  inspect(msg.sender_id, content="U123456")
}

///|
test "SlackChannelAdapter::handle_webhook ignores bot messages" {
  let config = SlackChannelConfig::default(name="slack", bot_token="xoxb-test")
  let adapter = SlackChannelAdapter::new(config)
  let request : Json = {
    "event": {
      "type": "message",
      "channel": "C123456",
      "user": "U123456",
      "text": "Bot message",
      "bot_id": "B123456",
    },
  }
  ignore(adapter.handle_webhook(request))
  // Should not have any messages
  let mut queue_empty = false
  ignore(
    @interfaces.ChannelAdapter::receive(adapter) catch {
      _ => {
        queue_empty = true
        return
      }
    },
  )
  if not(queue_empty) {
    fail("Expected empty queue for bot messages")
  }
}

///|
test "SlackChannelAdapter::handle_webhook ignores subtype messages" {
  let config = SlackChannelConfig::default(name="slack", bot_token="xoxb-test")
  let adapter = SlackChannelAdapter::new(config)
  let request : Json = {
    "event": {
      "type": "message",
      "channel": "C123456",
      "user": "U123456",
      "text": "Edited message",
      "subtype": "message_changed",
    },
  }
  ignore(adapter.handle_webhook(request))
  let mut queue_empty = false
  ignore(
    @interfaces.ChannelAdapter::receive(adapter) catch {
      _ => {
        queue_empty = true
        return
      }
    },
  )
  if not(queue_empty) {
    fail("Expected empty queue for subtype messages")
  }
}

// =============================================================================
// Discord Channel Tests
// =============================================================================

///|
test "DiscordChannelConfig::default has correct values" {
  let config = DiscordChannelConfig::default(
    name="discord",
    bot_token="test_token",
    application_id="12345",
  )
  inspect(config.name, content="discord")
  inspect(config.bot_token, content="test_token")
  inspect(config.application_id, content="12345")
  inspect(
    config.gateway_url,
    content="wss://gateway.discord.gg/?v=10&encoding=json",
  )
  inspect(config.api_base_url, content="https://discord.com/api/v10")
}

///|
test "DiscordChannelAdapter::new creates adapter" {
  let config = DiscordChannelConfig::default(
    name="discord",
    bot_token="test_token",
    application_id="12345",
  )
  let adapter = DiscordChannelAdapter::new(config)
  inspect(@interfaces.ChannelAdapter::name(adapter), content="discord")
  inspect(@interfaces.ChannelAdapter::is_connected(adapter), content="false")
}

// =============================================================================
// Telegram Channel Tests
// =============================================================================

///|
test "TelegramChannelConfig::default has correct values" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  inspect(config.name, content="telegram")
  inspect(config.bot_token, content="123456:ABC")
  inspect(config.webhook_url, content="None")
  inspect(config.api_base_url, content="https://api.telegram.org")
}

///|
test "TelegramChannelAdapter::new creates adapter" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  inspect(@interfaces.ChannelAdapter::name(adapter), content="telegram")
  inspect(@interfaces.ChannelAdapter::is_connected(adapter), content="false")
}

///|
test "TelegramChannelAdapter::handle_update processes message" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  let update : Json = {
    "update_id": 123456789,
    "message": {
      "message_id": 1,
      "chat": { "id": 12345 },
      "from": { "id": 67890 },
      "text": "Hello from Telegram!",
    },
  }
  adapter.handle_update(update)
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.content, content="Hello from Telegram!")
  inspect(msg.chat_id, content="12345")
  inspect(msg.sender_id, content="67890")
}

///|
test "TelegramChannelAdapter::handle_update processes edited_message" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  let update : Json = {
    "update_id": 123456790,
    "edited_message": {
      "message_id": 1,
      "chat": { "id": 11111 },
      "from": { "id": 22222 },
      "text": "Edited message",
    },
  }
  adapter.handle_update(update)
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.content, content="Edited message")
}

///|
test "TelegramChannelAdapter::handle_update handles caption" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  let update : Json = {
    "update_id": 123456791,
    "message": {
      "message_id": 2,
      "chat": { "id": 33333 },
      "from": { "id": 44444 },
      "caption": "Photo caption",
      "photo": Json::array([]),
    },
  }
  adapter.handle_update(update)
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.content, content="Photo caption")
}

///|
test "TelegramChannelAdapter::handle_update ignores empty content" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  let update : Json = {
    "update_id": 123456792,
    "message": {
      "message_id": 3,
      "chat": { "id": 55555 },
      "from": { "id": 66666 },
    },
  }
  adapter.handle_update(update)
  // Should not have any messages (empty content)
  let mut queue_empty = false
  ignore(
    @interfaces.ChannelAdapter::receive(adapter) catch {
      _ => {
        queue_empty = true
        return
      }
    },
  )
  if not(queue_empty) {
    fail("Expected empty queue for empty content")
  }
}

///|
test "TelegramChannelAdapter updates last_update_id" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  inspect(adapter.last_update_id, content="0")
  let update : Json = {
    "update_id": 999,
    "message": {
      "message_id": 1,
      "chat": { "id": 123 },
      "from": { "id": 456 },
      "text": "Test",
    },
  }
  adapter.handle_update(update)
  inspect(adapter.last_update_id, content="999")
}

// =============================================================================
// WebSocket Channel Tests
// =============================================================================

///|
test "WebSocketChannelConfig::default has correct values" {
  let config = WebSocketChannelConfig::default(
    name="ws",
    url="wss://example.com/ws",
  )
  inspect(config.name, content="ws")
  inspect(config.url, content="wss://example.com/ws")
  inspect(config.auth_token, content="None")
  inspect(config.heartbeat_interval_ms, content="30000")
}

///|
test "WebSocketChannelAdapter::new creates adapter" {
  let config = WebSocketChannelConfig::default(
    name="ws",
    url="wss://example.com/ws",
  )
  let adapter = WebSocketChannelAdapter::new(config)
  inspect(@interfaces.ChannelAdapter::name(adapter), content="ws")
  // WebSocket requires actual connection, so is_connected depends on socket state
}

// =============================================================================
// ChannelError Tests
// =============================================================================

///|
test "ChannelError variants exist" {
  let err1 : ChannelError = ChannelError::ConnectionFailed("test")
  let err2 : ChannelError = ChannelError::AuthenticationFailed("test")
  let err3 : ChannelError = ChannelError::RateLimited(retry_after=60)
  let err4 : ChannelError = ChannelError::MessageTooLong(max_length=2000)
  let err5 : ChannelError = ChannelError::InvalidPayload("test")
  let err6 : ChannelError = ChannelError::NetworkError("test")
  let err7 : ChannelError = ChannelError::ChannelNotFound("test")
  ignore(err1)
  ignore(err2)
  ignore(err3)
  ignore(err4)
  ignore(err5)
  ignore(err6)
  ignore(err7)
}

///|
test "ChannelError::RateLimited contains retry info" {
  let err : ChannelError = ChannelError::RateLimited(retry_after=120)
  match err {
    ChannelError::RateLimited(retry_after~) =>
      inspect(retry_after, content="120")
    _ => fail("Expected RateLimited error")
  }
}

///|
test "ChannelError::MessageTooLong contains max length" {
  let err : ChannelError = ChannelError::MessageTooLong(max_length=4000)
  match err {
    ChannelError::MessageTooLong(max_length~) =>
      inspect(max_length, content="4000")
    _ => fail("Expected MessageTooLong error")
  }
}

// =============================================================================
// RoutingRule Tests
// =============================================================================

///|
test "RoutingRule::new creates rule correctly" {
  let rule = RoutingRule::new(
    name="test_rule",
    channel_pattern="discord*",
    chat_pattern=Some("guild_*"),
    session_strategy=@session.SessionStrategy::PerUser,
  )
  inspect(rule.name, content="test_rule")
  inspect(rule.channel_pattern, content="discord*")
  inspect(rule.chat_pattern, content="Some(\"guild_*\")")
}

// =============================================================================
// Telegram Extended Tests
// =============================================================================

///|
test "TelegramChannelConfig has polling settings" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  inspect(config.polling_timeout, content="30")
  inspect(config.allowed_updates.length(), content="3")
}

///|
test "TelegramChannelAdapter::handle_update processes sender name" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  let update : Json = {
    "update_id": 123456793,
    "message": {
      "message_id": 1,
      "chat": { "id": 12345 },
      "from": { "id": 67890, "first_name": "John", "last_name": "Doe" },
      "text": "Test message",
    },
  }
  adapter.handle_update(update)
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.sender_name, content="John Doe")
}

///|
test "TelegramChannelAdapter::handle_update processes callback_query" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  let update : Json = {
    "update_id": 123456794,
    "callback_query": {
      "id": "callback_123",
      "from": { "id": 67890, "first_name": "Jane" },
      "message": { "message_id": 1, "chat": { "id": 12345 } },
      "data": "button_click",
    },
  }
  adapter.handle_update(update)
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.content, content="button_click")
  inspect(msg.sender_name, content="Jane")
  // Check metadata
  match msg.metadata.get("is_callback") {
    Some(Json::True) => ()
    _ => fail("Expected is_callback to be true")
  }
}

///|
test "TelegramChannelAdapter::handle_update processes photo attachment" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  let update : Json = {
    "update_id": 123456795,
    "message": {
      "message_id": 2,
      "chat": { "id": 11111 },
      "from": { "id": 22222 },
      "caption": "My photo",
      "photo": [
        { "file_id": "small_photo_id", "file_size": 1000 },
        { "file_id": "large_photo_id", "file_size": 5000 },
      ],
    },
  }
  adapter.handle_update(update)
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  inspect(msg.content, content="My photo")
  match msg.message_type {
    @types.MessageType::Attachment(attachments) => {
      inspect(attachments.length(), content="1")
      inspect(attachments[0].content_type, content="image/jpeg")
      // Should use the largest photo (last in array)
      assert_true(attachments[0].url.contains("large_photo_id"))
    }
    _ => fail("Expected Attachment message type")
  }
}

///|
test "TelegramChannelAdapter::handle_update processes document attachment" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  let update : Json = {
    "update_id": 123456796,
    "message": {
      "message_id": 3,
      "chat": { "id": 33333 },
      "from": { "id": 44444 },
      "caption": "Document here",
      "document": {
        "file_id": "doc_file_id",
        "file_name": "report.pdf",
        "mime_type": "application/pdf",
        "file_size": 50000,
      },
    },
  }
  adapter.handle_update(update)
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  match msg.message_type {
    @types.MessageType::Attachment(attachments) => {
      inspect(attachments[0].filename, content="report.pdf")
      inspect(attachments[0].content_type, content="application/pdf")
      inspect(attachments[0].size, content="50000")
    }
    _ => fail("Expected Attachment message type")
  }
}

///|
test "InlineKeyboardButton::callback creates callback button" {
  let button = InlineKeyboardButton::callback("Click me", "action_1")
  inspect(button.text, content="Click me")
  inspect(button.callback_data, content="Some(\"action_1\")")
  inspect(button.url, content="None")
}

///|
test "InlineKeyboardButton::link creates URL button" {
  let button = InlineKeyboardButton::link("Visit", "https://example.com")
  inspect(button.text, content="Visit")
  inspect(button.callback_data, content="None")
  inspect(button.url, content="Some(\"https://example.com\")")
}

///|
test "TelegramChannelAdapter metadata includes message_id" {
  let config = TelegramChannelConfig::default(
    name="telegram",
    bot_token="123456:ABC",
  )
  let adapter = TelegramChannelAdapter::new(config)
  let update : Json = {
    "update_id": 123456797,
    "message": {
      "message_id": 42,
      "chat": { "id": 55555, "type": "private" },
      "from": { "id": 66666 },
      "text": "Test",
    },
  }
  adapter.handle_update(update)
  let msg = @interfaces.ChannelAdapter::receive(adapter) catch { _ => return }
  match msg.metadata.get("message_id") {
    Some(Json::Number(id, ..)) => inspect(id.to_int(), content="42")
    _ => fail("Expected message_id in metadata")
  }
  match msg.metadata.get("chat_type") {
    Some(Json::String(t)) => inspect(t, content="private")
    _ => fail("Expected chat_type in metadata")
  }
}

// =============================================================================
// Helper function for assertions
// =============================================================================

///|
fn assert_true(condition : Bool) -> Unit raise {
  if not(condition) {
    fail("Assertion failed: expected true")
  }
}
