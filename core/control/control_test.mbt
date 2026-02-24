///|
/// Control Planeテスト

///|
test "GatewayState::to_string" {
  inspect(@interfaces.GatewayState::Stopped.to_string(), content="stopped")
  inspect(@interfaces.GatewayState::Running.to_string(), content="running")
  inspect(@interfaces.GatewayState::Starting.to_string(), content="starting")
  inspect(@interfaces.GatewayState::Stopping.to_string(), content="stopping")
  inspect(
    @interfaces.GatewayState::Error("test error").to_string(),
    content="error: test error",
  )
}

///|
test "GatewayState::is_running" {
  assert_true(@interfaces.GatewayState::Running.is_running())
  assert_false(@interfaces.GatewayState::Stopped.is_running())
  assert_false(@interfaces.GatewayState::Starting.is_running())
  assert_false(@interfaces.GatewayState::Stopping.is_running())
  assert_false(@interfaces.GatewayState::Error("test").is_running())
}

///|
test "GatewayStatus::stopped" {
  let status = @interfaces.GatewayStatus::stopped(version="1.0.0")
  assert_false(status.state.is_running())
  assert_true(status.health.is_empty())
  assert_eq(status.connected_channels.length(), 0)
  assert_eq(status.active_sessions, 0)
  assert_true(status.started_at.is_empty())
  assert_eq(status.version, "1.0.0")
}

///|
test "AuthContext::token_only" {
  let ctx = @interfaces.AuthContext::token_only("test-token")
  assert_eq(ctx.token, "test-token")
  assert_true(ctx.user_id.is_empty())
  assert_true(ctx.expires_at.is_empty())
}

///|
test "AuthContext::new" {
  let ctx = @interfaces.AuthContext::new(
    token="test-token",
    user_id=Some("user-123"),
    expires_at=Some(1234567890L),
  )
  assert_eq(ctx.token, "test-token")
  assert_eq(ctx.user_id, Some("user-123"))
  assert_eq(ctx.expires_at, Some(1234567890L))
}

///|
test "GatewayConfig::default" {
  let cfg = @interfaces.GatewayConfig::default()
  assert_eq(cfg.host, "127.0.0.1")
  assert_eq(cfg.port, 8080)
  assert_eq(cfg.auth_token, "")
  assert_true(cfg.auto_connect_channels)
}

///|
test "Gateway::new and status" {
  let gw = Gateway::with_components(
    channel_manager=None,
    session_resolver=None,
    session_store=None,
    health_aggregator=None,
    outbound_dispatcher=None,
    time_provider=None,
    agent_handler=None,
    version="0.1.0",
  )
  let status = gw.status()
  assert_false(status.state.is_running())
  assert_eq(status.version, "0.1.0")
}

///|
test "Gateway::minimal" {
  let gw = Gateway::minimal(version="0.1.0")
  let status = gw.status()
  assert_false(status.state.is_running())
  assert_eq(status.connected_channels.length(), 0)
}

///|
test "Gateway::start and stop" {
  let gw = Gateway::minimal(version="0.1.0")
  // 起動
  let cfg = @interfaces.GatewayConfig::default()
  gw.start(config=cfg)
  let status = gw.status()
  assert_true(status.state.is_running())
  // 停止
  gw.stop()
  let status2 = gw.status()
  assert_false(status2.state.is_running())
}

///|
test "Gateway::start already running" {
  let gw = Gateway::minimal(version="0.1.0")
  let cfg = @interfaces.GatewayConfig::default()
  gw.start(config=cfg)
  // 2回目の起動はエラー
  let result : Result[Unit, @interfaces.ControlError] = Ok(gw.start(config=cfg)) catch {
    e => Err(e)
  }
  assert_true(
    match result {
      Err(@interfaces.ControlError::AlreadyRunning) => true
      _ => false
    },
  )
}

///|
test "Gateway::stop already stopped" {
  let gw = Gateway::minimal(version="0.1.0")
  // 停止中に停止はエラー
  let result : Result[Unit, @interfaces.ControlError] = Ok(gw.stop()) catch {
    e => Err(e)
  }
  assert_true(
    match result {
      Err(@interfaces.ControlError::AlreadyStopped) => true
      _ => false
    },
  )
}

///|
test "Gateway::authenticate with empty token" {
  let gw = Gateway::minimal(version="0.1.0")
  let cfg = @interfaces.GatewayConfig::default()
  gw.start(config=cfg)
  // 空のauth_tokenは認証無効
  let result = gw.authenticate(token="any-token")
  assert_true(
    match result {
      @interfaces.AuthResult::Authenticated(_) => true
      _ => false
    },
  )
}

///|
test "Gateway::authenticate with valid token" {
  let gw = Gateway::minimal(version="0.1.0")
  let default_cfg = @interfaces.GatewayConfig::default()
  let cfg : @interfaces.GatewayConfig = {
    ..default_cfg,
    auth_token: "secret-token",
  }
  gw.start(config=cfg)
  // 正しいトークン
  let result = gw.authenticate(token="secret-token")
  assert_true(
    match result {
      @interfaces.AuthResult::Authenticated(ctx) => ctx.token == "secret-token"
      _ => false
    },
  )
}

///|
test "Gateway::authenticate with invalid token" {
  let gw = Gateway::minimal(version="0.1.0")
  let default_cfg = @interfaces.GatewayConfig::default()
  let cfg : @interfaces.GatewayConfig = {
    ..default_cfg,
    auth_token: "secret-token",
  }
  gw.start(config=cfg)
  // 不正なトークン
  let result = gw.authenticate(token="wrong-token")
  assert_true(
    match result {
      @interfaces.AuthResult::Denied(_) => true
      _ => false
    },
  )
}

///|
test "SimpleTokenAuthenticator::validate" {
  let auth = SimpleTokenAuthenticator::new(token="my-secret")
  // 正しいトークン
  let result = auth.validate(token="my-secret")
  assert_true(
    match result {
      @interfaces.AuthResult::Authenticated(_) => true
      _ => false
    },
  )
  // 不正なトークン
  let result2 = auth.validate(token="wrong")
  assert_true(
    match result2 {
      @interfaces.AuthResult::Denied(_) => true
      _ => false
    },
  )
}

///|
test "SimpleTokenAuthenticator::revoke" {
  let auth = SimpleTokenAuthenticator::new(token="my-secret")
  // 正しいトークンで認証成功
  let result = auth.validate(token="my-secret")
  assert_true(
    match result {
      @interfaces.AuthResult::Authenticated(_) => true
      _ => false
    },
  )
  // トークンを無効化
  auth.revoke(token="my-secret")
  // 無効化後は認証失敗
  let result2 = auth.validate(token="my-secret")
  assert_true(
    match result2 {
      @interfaces.AuthResult::Denied(_) => true
      _ => false
    },
  )
}

///|
test "NoAuthAuthenticator::validate" {
  let auth = NoAuthAuthenticator::new()
  // 任意のトークンで認証成功
  let result = auth.validate(token="anything")
  assert_true(
    match result {
      @interfaces.AuthResult::Authenticated(_) => true
      _ => false
    },
  )
}

///|
test "NoAuthAuthenticator::issue_token" {
  let auth = NoAuthAuthenticator::new()
  let token = auth.issue_token(user_id="user-123")
  assert_eq(token, "no-auth-token-user-123")
}
