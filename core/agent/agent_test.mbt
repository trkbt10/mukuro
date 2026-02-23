///|
/// Tests for agent state and loop context
test "AgentState::default is Idle" {
  let state : @agent.AgentState = @agent.AgentState::Idle
  inspect(state, content="Idle")
}

///|
test "AgentState::Show for all variants" {
  inspect(@agent.AgentState::Idle, content="Idle")
  inspect(@agent.AgentState::WaitingForModel, content="WaitingForModel")
  inspect(@agent.AgentState::SendingResponse, content="SendingResponse")
  inspect(
    @agent.AgentState::ExecutingTool(tool_name="test_tool", call_id="call_1"),
    content="ExecutingTool(test_tool, call_1)",
  )
  inspect(@agent.AgentState::Error("test error"), content="Error(test error)")
  inspect(@agent.AgentState::Completed, content="Completed")
}

///|
test "AgentLoopContext::new creates valid context" {
  let ctx = @agent.AgentLoopContext::new()
  inspect(ctx.state, content="Idle")
  inspect(ctx.iteration, content="0")
  inspect(ctx.messages.length(), content="0")
  inspect(ctx.tool_call_history.length(), content="0")
}

///|
test "AgentLoopContext::set_state updates state" {
  let ctx = @agent.AgentLoopContext::new()
  ctx.set_state(@agent.AgentState::WaitingForModel)
  inspect(ctx.state, content="WaitingForModel")
  ctx.set_state(
    @agent.AgentState::ExecutingTool(tool_name="my_tool", call_id="call_1"),
  )
  inspect(ctx.state, content="ExecutingTool(my_tool, call_1)")
}

///|
test "AgentLoopContext::increment_iteration" {
  let ctx = @agent.AgentLoopContext::new()
  inspect(ctx.iteration, content="0")
  ctx.increment_iteration()
  inspect(ctx.iteration, content="1")
  ctx.increment_iteration()
  ctx.increment_iteration()
  inspect(ctx.iteration, content="3")
}

///|
test "AgentLoopContext::add_message" {
  let ctx = @agent.AgentLoopContext::new()
  let msg1 = @types.ModelMessage::User(content="Hello", name=None)
  ctx.add_message(msg1)
  inspect(ctx.messages.length(), content="1")
  let msg2 = @types.ModelMessage::Assistant(content="Hi there", tool_calls=None)
  ctx.add_message(msg2)
  inspect(ctx.messages.length(), content="2")
}

///|
test "AgentLoopContext::record_tool_call" {
  let ctx = @agent.AgentLoopContext::new()
  let call = @types.ToolCallRequest::new(
    id="call_1",
    name="test_tool",
    arguments=Json::null(),
  )
  ctx.record_tool_call(call)
  inspect(ctx.tool_call_history.length(), content="1")
}

///|
test "AgentLoopContext::is_max_iterations" {
  let ctx = @agent.AgentLoopContext::new()

  // Initially at 0, max 5
  inspect(ctx.is_max_iterations(5), content="false")

  // Increment to 5
  for _ in 0..<5 {
    ctx.increment_iteration()
  }
  inspect(ctx.is_max_iterations(5), content="true")

  // Still under max 10
  inspect(ctx.is_max_iterations(10), content="false")
}

///|
test "AgentLoopContext::is_error" {
  let ctx = @agent.AgentLoopContext::new()

  // Initially Idle - not an error
  inspect(ctx.is_error(), content="false")

  // WaitingForModel - not an error
  ctx.set_state(@agent.AgentState::WaitingForModel)
  inspect(ctx.is_error(), content="false")

  // Error state
  ctx.set_state(@agent.AgentState::Error("something went wrong"))
  inspect(ctx.is_error(), content="true")
}

///|
test "AgentLoopContext::is_completed" {
  let ctx = @agent.AgentLoopContext::new()

  // Initially Idle - not completed
  inspect(ctx.is_completed(), content="false")

  // WaitingForModel - not completed
  ctx.set_state(@agent.AgentState::WaitingForModel)
  inspect(ctx.is_completed(), content="false")

  // Completed state
  ctx.set_state(@agent.AgentState::Completed)
  inspect(ctx.is_completed(), content="true")
}
