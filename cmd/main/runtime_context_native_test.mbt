///|
/// Workspace context注入（native）テスト

///|
fn write_text(path : String, content : String) -> Bool {
  @native.c_write_text_file(
    @native.string_to_cstring(path),
    @native.string_to_cstring(content),
  ) ==
  0
}

///|
fn cleanup_file(path : String) -> Unit {
  ignore(@native.c_remove_file(@native.string_to_cstring(path)))
}

///|
fn cleanup_workspace_context_files() -> Unit {
  cleanup_file(".mukuro/test-runtime-context/bootstrap.md")
  cleanup_file(".mukuro/test-runtime-context/memory.json")
  cleanup_file(".mukuro/test-runtime-context/memory.txt")
  cleanup_file(".mukuro/test-runtime-context/skills.json")
}

///|
test "enrich_envelope_with_workspace_context_impl injects bootstrap/memory/skills" {
  set_workspace_context_dir_for_process(".mukuro/test-runtime-context")
  cleanup_workspace_context_files()
  assert_true(
    write_text(
      ".mukuro/test-runtime-context/bootstrap.md", "You are workspace agent",
    ),
  )
  assert_true(
    write_text(
      ".mukuro/test-runtime-context/memory.json", "[\"loves tea\", \"uses vim\"]",
    ),
  )
  assert_true(
    write_text(
      ".mukuro/test-runtime-context/skills.json", "[{\"name\":\"web_search\",\"description\":\"search\",\"instructions\":\"latest\"}]",
    ),
  )

  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-ctx",
    sender_id: "user-ctx",
    sender_name: "User",
    content: "hello",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 1000L,
  }
  let enriched = enrich_envelope_with_workspace_context_impl(envelope)
  assert_true(
    match enriched.metadata.get("bootstrap") {
      Some(String(s)) => s.contains("workspace agent")
      _ => false
    },
  )
  assert_true(
    match enriched.metadata.get("memory_context") {
      Some(Array(items)) => items.length() >= 2
      _ => false
    },
  )
  assert_true(
    match enriched.metadata.get("skills") {
      Some(Array(items)) => items.length() == 1
      _ => false
    },
  )
  cleanup_workspace_context_files()
  set_workspace_context_dir_for_process(".mukuro")
}

///|
test "enrich_envelope_with_workspace_context_impl keeps existing metadata override" {
  set_workspace_context_dir_for_process(".mukuro/test-runtime-context")
  cleanup_workspace_context_files()
  assert_true(
    write_text(
      ".mukuro/test-runtime-context/bootstrap.md", "workspace bootstrap",
    ),
  )

  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-ctx-2",
    sender_id: "user-ctx-2",
    sender_name: "User2",
    content: "hello",
    message_type: @types.MessageType::Text,
    metadata: { "bootstrap": Json::string("metadata bootstrap") },
    timestamp: 2000L,
  }
  let enriched = enrich_envelope_with_workspace_context_impl(envelope)
  assert_true(
    match enriched.metadata.get("bootstrap") {
      Some(String(s)) => s == "metadata bootstrap"
      _ => false
    },
  )
  cleanup_workspace_context_files()
  set_workspace_context_dir_for_process(".mukuro")
}
