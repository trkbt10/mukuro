///|
/// Child Session Tests

///|
test "ChildSessionStatus show" {
  inspect!(@session.ChildSessionStatus::Pending.to_string(), content="pending")
  inspect!(@session.ChildSessionStatus::Running.to_string(), content="running")
  inspect!(
    @session.ChildSessionStatus::Completed.to_string(),
    content="completed",
  )
  inspect!(
    @session.ChildSessionStatus::Cancelled.to_string(),
    content="cancelled",
  )
  inspect!(
    @session.ChildSessionStatus::Failed("error message").to_string(),
    content="failed: error message",
  )
}

///|
test "ChildSession new creates with correct values" {
  let session = @session.ChildSession::new(
    parent_id="parent_1",
    child_id="child_1",
    timestamp=1000L,
  )
  inspect!(session.parent_id, content="parent_1")
  inspect!(session.child_id, content="child_1")
  inspect!(session.messages.length(), content="0")
  inspect!(session.created_at, content="1000")
  inspect!(session.updated_at, content="1000")
  assert_true!(session.result.is_empty())
}

///|
test "ChildSession initial status is Pending" {
  let session = @session.ChildSession::new(
    parent_id="p", child_id="c", timestamp=0L,
  )
  match session.status {
    @session.ChildSessionStatus::Pending => ()
    _ => @test.fail("Expected Pending status")
  }
}

///|
test "ChildSession add_message" {
  let session = @session.ChildSession::new(
    parent_id="p", child_id="c", timestamp=0L,
  )
  session.add_message(@types.ModelMessage::System("Hello"))
  session.add_message(
    @types.ModelMessage::User(content="Hi", name=None),
  )
  inspect!(session.messages.length(), content="2")
}

///|
test "ChildSession set_status" {
  let session = @session.ChildSession::new(
    parent_id="p", child_id="c", timestamp=100L,
  )
  session.set_status(@session.ChildSessionStatus::Running, 200L)
  match session.status {
    @session.ChildSessionStatus::Running => ()
    _ => @test.fail("Expected Running status")
  }
  inspect!(session.updated_at, content="200")
}

///|
test "ChildSession set_result" {
  let session = @session.ChildSession::new(
    parent_id="p", child_id="c", timestamp=100L,
  )
  session.set_result("Done", 300L)
  match session.status {
    @session.ChildSessionStatus::Completed => ()
    _ => @test.fail("Expected Completed status")
  }
  match session.result {
    Some(r) => inspect!(r, content="Done")
    None => @test.fail("Expected result")
  }
  inspect!(session.updated_at, content="300")
}

///|
test "ChildSession set_failed" {
  let session = @session.ChildSession::new(
    parent_id="p", child_id="c", timestamp=100L,
  )
  session.set_failed("Error occurred", 400L)
  match session.status {
    @session.ChildSessionStatus::Failed(msg) =>
      inspect!(msg, content="Error occurred")
    _ => @test.fail("Expected Failed status")
  }
  inspect!(session.updated_at, content="400")
}

///|
test "ChildSession cancel" {
  let session = @session.ChildSession::new(
    parent_id="p", child_id="c", timestamp=100L,
  )
  session.cancel(500L)
  match session.status {
    @session.ChildSessionStatus::Cancelled => ()
    _ => @test.fail("Expected Cancelled status")
  }
  inspect!(session.updated_at, content="500")
}

///|
test "ChildSession is_finished" {
  let session = @session.ChildSession::new(
    parent_id="p", child_id="c", timestamp=0L,
  )
  assert_false!(session.is_finished())
  session.set_status(@session.ChildSessionStatus::Running, 100L)
  assert_false!(session.is_finished())
  session.set_status(@session.ChildSessionStatus::Completed, 200L)
  assert_true!(session.is_finished())
}

///|
test "ChildSession is_finished for all terminal states" {
  let s1 = @session.ChildSession::new(
    parent_id="p", child_id="c1", timestamp=0L,
  )
  s1.status = @session.ChildSessionStatus::Completed
  assert_true!(s1.is_finished())
  let s2 = @session.ChildSession::new(
    parent_id="p", child_id="c2", timestamp=0L,
  )
  s2.status = @session.ChildSessionStatus::Failed("error")
  assert_true!(s2.is_finished())
  let s3 = @session.ChildSession::new(
    parent_id="p", child_id="c3", timestamp=0L,
  )
  s3.status = @session.ChildSessionStatus::Cancelled
  assert_true!(s3.is_finished())
}

///|
test "ChildSessionManager new" {
  let manager = @session.ChildSessionManager::new(parent_id="main")
  inspect!(manager.parent_id, content="main")
  inspect!(manager.next_id, content="1")
  inspect!(manager.sessions.size(), content="0")
}

///|
test "ChildSessionManager generate_id" {
  let manager = @session.ChildSessionManager::new(parent_id="main")
  let id1 = manager.generate_id()
  let id2 = manager.generate_id()
  inspect!(id1, content="child_main_1")
  inspect!(id2, content="child_main_2")
}

///|
test "ChildSessionManager create_session" {
  let manager = @session.ChildSessionManager::new(parent_id="main")
  let session = manager.create_session(1000L)
  inspect!(session.parent_id, content="main")
  inspect!(session.child_id, content="child_main_1")
  inspect!(manager.sessions.size(), content="1")
}

///|
test "ChildSessionManager get_session" {
  let manager = @session.ChildSessionManager::new(parent_id="main")
  let session = manager.create_session(1000L)
  let child_id = session.child_id
  match manager.get_session(child_id) {
    Some(s) => inspect!(s.parent_id, content="main")
    None => @test.fail("Expected session")
  }
  match manager.get_session("nonexistent") {
    Some(_) => @test.fail("Expected None")
    None => ()
  }
}

///|
test "ChildSessionManager list_sessions" {
  let manager = @session.ChildSessionManager::new(parent_id="main")
  let _ = manager.create_session(100L)
  let _ = manager.create_session(200L)
  let _ = manager.create_session(300L)
  let sessions = manager.list_sessions()
  inspect!(sessions.length(), content="3")
}

///|
test "ChildSessionManager list_active_sessions" {
  let manager = @session.ChildSessionManager::new(parent_id="main")
  let s1 = manager.create_session(100L)
  let s2 = manager.create_session(200L)
  let s3 = manager.create_session(300L)
  // All are active (Pending)
  inspect!(manager.list_active_sessions().length(), content="3")
  // Complete one
  s1.status = @session.ChildSessionStatus::Completed
  inspect!(manager.list_active_sessions().length(), content="2")
  // Fail another
  s2.status = @session.ChildSessionStatus::Failed("error")
  inspect!(manager.list_active_sessions().length(), content="1")
  // Cancel the last
  s3.status = @session.ChildSessionStatus::Cancelled
  inspect!(manager.list_active_sessions().length(), content="0")
}

///|
test "ChildSessionManager remove_session" {
  let manager = @session.ChildSessionManager::new(parent_id="main")
  let session = manager.create_session(100L)
  let child_id = session.child_id
  inspect!(manager.sessions.size(), content="1")
  assert_true!(manager.remove_session(child_id))
  inspect!(manager.sessions.size(), content="0")
  // Removing again should return false
  assert_false!(manager.remove_session(child_id))
}
