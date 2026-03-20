///|
test "McpServerConfig from_json parses correctly" {
  let json : Json = {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem"],
    "env": { "HOME": "/tmp" },
    "cwd": "/workspace",
  }
  match McpServerConfig::from_json("test-server", json) {
    Some(config) => {
      inspect(config.name, content="test-server")
      inspect(config.command, content="npx")
      inspect(config.args.length(), content="2")
      inspect(config.env.length(), content="1")
      match config.cwd {
        Some(cwd) => inspect(cwd, content="/workspace")
        None => fail("Expected cwd")
      }
    }
    None => fail("Expected Some")
  }
}

///|
test "McpServerConfig from_json minimal" {
  let json : Json = { "command": "python3" }
  match McpServerConfig::from_json("minimal", json) {
    Some(config) => {
      inspect(config.name, content="minimal")
      inspect(config.command, content="python3")
      inspect(config.args.length(), content="0")
    }
    None => fail("Expected Some")
  }
}

///|
test "McpServerConfig from_json rejects missing command" {
  let json : Json = { "args": ["test"] }
  inspect(McpServerConfig::from_json("bad", json) is None, content="true")
}

///|
test "McpToolDef to_tool_definition" {
  let tool : McpToolDef = {
    name: "read_file",
    description: "Read a file",
    input_schema: { "type": "object", "properties": { "path": { "type": "string" } } },
    server_name: "fs",
  }
  let def = tool.to_tool_definition()
  inspect(def.name, content="mcp_fs_read_file")
  inspect(def.description.contains("[MCP:fs]"), content="true")
}

///|
test "parse_tools_list_response extracts tools" {
  let json : Json = {
    "tools": [
      {
        "name": "read_file",
        "description": "Read a file",
        "inputSchema": { "type": "object" },
      },
      { "name": "write_file", "description": "Write a file" },
    ],
  }
  let tools = parse_tools_list_response(json, "fs")
  inspect(tools.length(), content="2")
  inspect(tools[0].name, content="read_file")
  inspect(tools[0].server_name, content="fs")
}

///|
test "parse_tool_call_result extracts text content" {
  let json : Json = {
    "content": [
      { "type": "text", "text": "File content here" },
      { "type": "text", "text": "More content" },
    ],
  }
  let result = parse_tool_call_result(json)
  inspect(result.contains("File content here"), content="true")
  inspect(result.contains("More content"), content="true")
}

///|
test "resolve_mcp_tool_name extracts tool name" {
  match resolve_mcp_tool_name("mcp_fs_read_file", "fs") {
    Some(name) => inspect(name, content="read_file")
    None => fail("Expected Some")
  }
}

///|
test "resolve_mcp_tool_name rejects wrong server" {
  inspect(
    resolve_mcp_tool_name("mcp_other_read_file", "fs") is None,
    content="true",
  )
}

///|
test "resolve_mcp_tool_name rejects non-mcp name" {
  inspect(resolve_mcp_tool_name("shell", "fs") is None, content="true")
}

///|
test "parse_tools_list_response handles empty tools array" {
  let json : Json = { "tools": [] }
  let tools = parse_tools_list_response(json, "empty")
  inspect(tools.length(), content="0")
}

///|
test "parse_tools_list_response handles missing tools key" {
  let json : Json = { "other": "data" }
  let tools = parse_tools_list_response(json, "bad")
  inspect(tools.length(), content="0")
}

///|
test "parse_tool_call_result handles non-array content" {
  let json : Json = { "result": "plain text" }
  let result = parse_tool_call_result(json)
  // non-matching format should stringify
  inspect(result.length() > 0, content="true")
}

///|
test "McpClient::new creates client" {
  let config : McpServerConfig = {
    name: "test",
    command: "echo",
    args: [],
    env: {},
    cwd: None,
  }
  let client = McpClient::new(config)
  inspect(client.config.name, content="test")
  inspect(client.initialized, content="false")
  inspect(client.tools.length(), content="0")
}
