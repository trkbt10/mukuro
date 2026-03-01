///|
/// Workspace context注入（native）テスト

///|
fn write_text(path : String, content : String) -> Bool {
  @native.c_write_text_file_bytes(
    @native.string_to_utf8_cstring(path),
    @native.string_to_utf8_cstring(content),
  ) ==
  0
}

///|
fn cleanup_file(path : String) -> Unit {
  ignore(@native.c_remove_file_bytes(@native.string_to_utf8_cstring(path)))
}

///|
fn cleanup_workspace_context_files() -> Unit {
  cleanup_file(".mukuro/test-runtime-context/bootstrap.md")
  cleanup_file(".mukuro/test-runtime-context/memory.json")
  cleanup_file(".mukuro/test-runtime-context/memory.txt")
  cleanup_file(".mukuro/test-runtime-context/skills.json")
  // OpenClaw互換ファイル
  cleanup_file(".mukuro/test-runtime-context/SOUL.md")
  cleanup_file(".mukuro/test-runtime-context/AGENTS.md")
  cleanup_file(".mukuro/test-runtime-context/TOOLS.md")
  cleanup_file(".mukuro/test-runtime-context/IDENTITY.md")
  cleanup_file(".mukuro/test-runtime-context/USER.md")
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

// ============================================================
// OpenClaw互換コンテキストファイルテスト
// ============================================================

///|
test "enrich_envelope_with_workspace_context_impl injects context_files" {
  set_workspace_context_dir_for_process(".mukuro/test-runtime-context")
  cleanup_workspace_context_files()
  // 各ファイルを作成
  assert_true(
    write_text(".mukuro/test-runtime-context/SOUL.md", "Be helpful and kind"),
  )
  assert_true(
    write_text(
      ".mukuro/test-runtime-context/AGENTS.md", "Follow code standards",
    ),
  )
  assert_true(
    write_text(".mukuro/test-runtime-context/TOOLS.md", "Use pnpm for packages"),
  )
  assert_true(
    write_text(
      ".mukuro/test-runtime-context/IDENTITY.md", "You are Mukuro Assistant",
    ),
  )
  assert_true(
    write_text(".mukuro/test-runtime-context/USER.md", "User prefers dark mode"),
  )

  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-ctx-files",
    sender_id: "user-ctx-files",
    sender_name: "User",
    content: "hello",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 3000L,
  }
  let enriched = enrich_envelope_with_workspace_context_impl(envelope)
  // soulキーが存在することを確認
  assert_true(
    match enriched.metadata.get("soul") {
      Some(String(s)) => s.contains("helpful")
      _ => false
    },
  )
  // agents_handbookキーが存在することを確認
  assert_true(
    match enriched.metadata.get("agents_handbook") {
      Some(String(s)) => s.contains("code standards")
      _ => false
    },
  )
  // tools_configキーが存在することを確認
  assert_true(
    match enriched.metadata.get("tools_config") {
      Some(String(s)) => s.contains("pnpm")
      _ => false
    },
  )
  // identityキーが存在することを確認
  assert_true(
    match enriched.metadata.get("identity") {
      Some(String(s)) => s.contains("Mukuro Assistant")
      _ => false
    },
  )
  // user_contextキーが存在することを確認
  assert_true(
    match enriched.metadata.get("user_context") {
      Some(String(s)) => s.contains("dark mode")
      _ => false
    },
  )
  cleanup_workspace_context_files()
  set_workspace_context_dir_for_process(".mukuro")
}

///|
test "enrich_envelope_with_workspace_context_impl ignores empty context_files" {
  set_workspace_context_dir_for_process(".mukuro/test-runtime-context")
  cleanup_workspace_context_files()
  // 空白のみのファイルを作成
  assert_true(write_text(".mukuro/test-runtime-context/SOUL.md", "   "))
  // 内容のあるファイルを作成
  assert_true(
    write_text(".mukuro/test-runtime-context/IDENTITY.md", "Real identity"),
  )

  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-empty-files",
    sender_id: "user-empty-files",
    sender_name: "User",
    content: "hello",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 4000L,
  }
  let enriched = enrich_envelope_with_workspace_context_impl(envelope)
  // 空白のみのsoulは注入されない
  inspect(enriched.metadata.contains("soul"), content="false")
  // 内容のあるidentityは注入される
  assert_true(
    match enriched.metadata.get("identity") {
      Some(String(s)) => s.contains("Real identity")
      _ => false
    },
  )
  cleanup_workspace_context_files()
  set_workspace_context_dir_for_process(".mukuro")
}

///|
test "enrich_envelope_with_workspace_context_impl respects metadata override" {
  // 既存メタデータが優先される（ワークスペースファイルで上書きされない）
  set_workspace_context_dir_for_process(".mukuro/test-runtime-context")
  cleanup_workspace_context_files()
  // ワークスペースにファイルを作成
  assert_true(
    write_text(".mukuro/test-runtime-context/SOUL.md", "Workspace soul"),
  )
  assert_true(
    write_text(".mukuro/test-runtime-context/IDENTITY.md", "Workspace identity"),
  )

  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-override",
    sender_id: "user-override",
    sender_name: "User",
    content: "hello",
    message_type: @types.MessageType::Text,
    metadata: {
      // 既存のsoulメタデータ（これが優先されるべき）
      "soul": Json::string("API-provided soul"),
    },
    timestamp: 5000L,
  }
  let enriched = enrich_envelope_with_workspace_context_impl(envelope)
  // 既存メタデータが優先される
  assert_true(
    match enriched.metadata.get("soul") {
      Some(String(s)) => s == "API-provided soul"
      _ => false
    },
  )
  // 既存がないidentityはワークスペースから注入される
  assert_true(
    match enriched.metadata.get("identity") {
      Some(String(s)) => s.contains("Workspace identity")
      _ => false
    },
  )
  cleanup_workspace_context_files()
  set_workspace_context_dir_for_process(".mukuro")
}

///|
test "enrich_envelope_with_workspace_context_impl handles missing files gracefully" {
  // ファイルが存在しない場合はメタデータキーが追加されない
  set_workspace_context_dir_for_process(".mukuro/test-runtime-context")
  cleanup_workspace_context_files()
  // ファイルを一切作成しない

  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-no-files",
    sender_id: "user-no-files",
    sender_name: "User",
    content: "hello",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 6000L,
  }
  let enriched = enrich_envelope_with_workspace_context_impl(envelope)
  // 全てのcontext_filesキーが存在しない
  inspect(enriched.metadata.contains("soul"), content="false")
  inspect(enriched.metadata.contains("agents_handbook"), content="false")
  inspect(enriched.metadata.contains("tools_config"), content="false")
  inspect(enriched.metadata.contains("identity"), content="false")
  inspect(enriched.metadata.contains("user_context"), content="false")
  set_workspace_context_dir_for_process(".mukuro")
}
