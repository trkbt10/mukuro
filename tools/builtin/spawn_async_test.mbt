///|
/// Async Sub-Agent Tests

///|
test "AsyncSubAgentConfig default values" {
  let config = @builtin.AsyncSubAgentConfig::default(name="test_agent")
  inspect(config.name, content="test_agent")
  inspect(config.system_prompt, content="You are a helpful assistant.")
  inspect(config.max_turns, content="10")
  inspect(config.allowed_tools.length(), content="0")
}

///|
test "AsyncSubAgentConfig with custom values" {
  let config : @builtin.AsyncSubAgentConfig = {
    name: "custom_agent",
    system_prompt: "You are a code reviewer.",
    max_turns: 5,
    allowed_tools: ["read_file", "write_file"],
  }
  inspect(config.name, content="custom_agent")
  inspect(config.max_turns, content="5")
  inspect(config.allowed_tools.length(), content="2")
}

///|
test "SubAgentManager generate_id increments" {
  let manager = @builtin.SubAgentManager::new()
  let id1 = manager.generate_id()
  let id2 = manager.generate_id()
  let id3 = manager.generate_id()
  inspect(id1, content="agent_1")
  inspect(id2, content="agent_2")
  inspect(id3, content="agent_3")
}

///|
test "SubAgentManager stores and retrieves agents" {
  let manager = @builtin.SubAgentManager::new()
  let id = manager.generate_id()
  let result : @builtin.SpawnResult = {
    agent_id: id,
    status: "running",
    response: None,
  }
  manager.agents[id] = result
  match manager.agents.get(id) {
    Some(r) => {
      inspect(r.agent_id, content="agent_1")
      inspect(r.status, content="running")
    }
    None => @test.fail("Agent not found")
  }
}

///|
test "SpawnResult with response" {
  let result : @builtin.SpawnResult = {
    agent_id: "agent_1",
    status: "completed",
    response: Some("Task completed successfully"),
  }
  inspect(result.agent_id, content="agent_1")
  inspect(result.status, content="completed")
  match result.response {
    Some(r) => inspect(r, content="Task completed successfully")
    None => @test.fail("Expected response")
  }
}

///|
test "SpawnResult without response" {
  let result : @builtin.SpawnResult = {
    agent_id: "agent_2",
    status: "running",
    response: None,
  }
  inspect(result.status, content="running")
  assert_true(result.response is None)
}

///|
test "SubAgentConfig default values" {
  let config = @builtin.SubAgentConfig::default(name="test")
  inspect(config.name, content="test")
  inspect(config.system_prompt, content="You are a helpful assistant.")
  inspect(config.model, content="default")
  inspect(config.max_turns, content="10")
  inspect(config.tools.length(), content="0")
}

///|
test "spawn_tool_definition" {
  let def = @builtin.spawn_tool_definition()
  inspect(def.name, content="spawn")
  assert_true(def.description.length() > 0)
}
