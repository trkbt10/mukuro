///|
test "InMemoryToolRegistry registers and retrieves tools" {
  let registry = InMemoryToolRegistry::new()
  let definition = @llm_types.ToolDefinition::new(
    name="echo",
    description="Echo the input",
    parameters={ "type": "object" },
  )
  // ダミーのエグゼキュータを作成
  let executor = DummyExecutor::new()
  @interfaces.ToolRegistry::register(registry, definition, executor)
  inspect(@interfaces.ToolRegistry::has_tool(registry, "echo"), content="true")
  inspect(
    @interfaces.ToolRegistry::has_tool(registry, "unknown"),
    content="false",
  )
}

///|
test "InMemoryToolRegistry lists definitions" {
  let registry = InMemoryToolRegistry::new()
  let def1 = @llm_types.ToolDefinition::new(
    name="tool1",
    description="Tool 1",
    parameters={},
  )
  let def2 = @llm_types.ToolDefinition::new(
    name="tool2",
    description="Tool 2",
    parameters={},
  )
  let executor = DummyExecutor::new()
  @interfaces.ToolRegistry::register(registry, def1, executor)
  @interfaces.ToolRegistry::register(registry, def2, executor)
  let defs = @interfaces.ToolRegistry::list_definitions(registry)
  inspect(defs.length(), content="2")
}

///|
test "InMemoryToolRegistry count returns correct value" {
  let registry = InMemoryToolRegistry::new()
  inspect(registry.count(), content="0")
  let def = @llm_types.ToolDefinition::new(name="test", description="Test", parameters={})
  let executor = DummyExecutor::new()
  @interfaces.ToolRegistry::register(registry, def, executor)
  inspect(registry.count(), content="1")
}

///|
test "tool_result_to_message creates correct message" {
  let result = @types.ToolResult::Success(content="Result data")
  let msg = tool_result_to_message("call_123", result)
  match msg {
    @llm_types.ModelMessage::ToolResult(tool_call_id~, content~) => {
      inspect(tool_call_id, content="call_123")
      inspect(content, content="Result data")
    }
    _ => fail("Expected ToolResult message")
  }
}

///|
test "is_success returns true for Success" {
  let result = @types.ToolResult::Success(content="OK")
  inspect(is_success(result), content="true")
  inspect(is_error(result), content="false")
}

///|
test "is_error returns true for Error" {
  let result = @types.ToolResult::Error(message="Failed")
  inspect(is_success(result), content="false")
  inspect(is_error(result), content="true")
}

// ダミーのエグゼキュータ（テスト用）

///|
struct DummyExecutor {
  _placeholder : Unit
}

///|
fn DummyExecutor::new() -> DummyExecutor {
  { _placeholder: () }
}

///|
impl @interfaces.ToolExecutor for DummyExecutor with execute(
  _self,
  tool_name~,
  arguments~,
  context~,
) {
  ignore(arguments)
  ignore(context)
  @types.ToolResult::Success(content="Executed: \{tool_name}")
}
