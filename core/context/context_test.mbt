///|
test "DefaultContextBuilder builds messages with system prompt" {
  let builder = DefaultContextBuilder::default()
  let input : @interfaces.ContextInput = {
    session_history: [],
    memory_context: [],
    skills: [],
    bootstrap: "You are a helpful assistant.",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "Hello",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 1000L,
    },
    system_prompt_config: None,
    is_first_message: true,
    context_files: @interfaces.ContextFiles::empty(),
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  // システムメッセージ + ユーザーメッセージ
  inspect(messages.length(), content="2")
}

///|
test "DefaultContextBuilder includes history" {
  // ビルトインツールガイドを無効化して履歴のみテスト
  let builder = DefaultContextBuilder::new(
    options={
      ..ContextOptions::default(),
      include_builtin_tools_guide: false,
    },
  )
  let history = [
    @types.ModelMessage::User(content="Hi", name=None),
    @types.ModelMessage::Assistant(content="Hello!", tool_calls=None),
  ]
  let input : @interfaces.ContextInput = {
    session_history: history,
    memory_context: [],
    skills: [],
    bootstrap: "",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "How are you?",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 2000L,
    },
    system_prompt_config: None,
    is_first_message: false,
    context_files: @interfaces.ContextFiles::empty(),
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  // 履歴2件 + 現在のメッセージ1件
  inspect(messages.length(), content="3")
}

///|
test "SkillLoader registers and retrieves skills" {
  let loader = SkillLoader::new()
  let skill = create_skill(
    name="search",
    description="Search the web",
    instructions="Use this to search",
  )
  loader.register(skill)
  inspect(loader.has("search"), content="true")
  inspect(loader.has("unknown"), content="false")
}

///|
test "SkillLoader lists all skills" {
  let loader = SkillLoader::new()
  loader.register(
    create_skill(name="skill1", description="Skill 1", instructions=""),
  )
  loader.register(
    create_skill(name="skill2", description="Skill 2", instructions=""),
  )
  let skills = loader.list()
  inspect(skills.length(), content="2")
}

///|
test "parse_skill_from_json parses valid JSON" {
  let json : Json = {
    "name": "test_skill",
    "description": "A test skill",
    "instructions": "Do something",
  }
  let skill = parse_skill_from_json(json)
  match skill {
    Some(s) => {
      inspect(s.name, content="test_skill")
      inspect(s.description, content="A test skill")
    }
    None => fail("Expected Some")
  }
}

///|
test "SystemPromptMode::Replace replaces bootstrap" {
  let builder = DefaultContextBuilder::default()
  let input : @interfaces.ContextInput = {
    session_history: [],
    memory_context: [],
    skills: [],
    bootstrap: "Original bootstrap",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "Hello",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 1000L,
    },
    system_prompt_config: Some({
      mode: @types.SystemPromptMode::Replace,
      when: @types.SystemPromptWhen::Always,
      content: "Custom prompt",
    }),
    is_first_message: true,
    context_files: @interfaces.ContextFiles::empty(),
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  // System message should contain custom prompt, not original
  match messages[0] {
    @types.ModelMessage::System(content) => {
      inspect(content.contains("Custom prompt"), content="true")
      inspect(content.contains("Original bootstrap"), content="false")
    }
    _ => fail("Expected system message")
  }
}

///|
test "SystemPromptMode::Append appends to bootstrap" {
  let builder = DefaultContextBuilder::default()
  let input : @interfaces.ContextInput = {
    session_history: [],
    memory_context: [],
    skills: [],
    bootstrap: "Original",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "Hello",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 1000L,
    },
    system_prompt_config: Some({
      mode: @types.SystemPromptMode::Append,
      when: @types.SystemPromptWhen::Always,
      content: "Additional",
    }),
    is_first_message: true,
    context_files: @interfaces.ContextFiles::empty(),
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  match messages[0] {
    @types.ModelMessage::System(content) => {
      // Both original and additional should be present
      inspect(content.contains("Original"), content="true")
      inspect(content.contains("Additional"), content="true")
    }
    _ => fail("Expected system message")
  }
}

///|
test "SystemPromptWhen::First only applies on first message" {
  let builder = DefaultContextBuilder::default()
  // Not first message - system prompt should not be applied
  let input : @interfaces.ContextInput = {
    session_history: [@types.ModelMessage::User(content="Previous", name=None)],
    memory_context: [],
    skills: [],
    bootstrap: "",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "Hello",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 2000L,
    },
    system_prompt_config: Some({
      mode: @types.SystemPromptMode::Replace,
      when: @types.SystemPromptWhen::First,
      content: "Should not appear",
    }),
    is_first_message: false,
    context_files: @interfaces.ContextFiles::empty(),
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  // No system message should be added
  match messages[0] {
    @types.ModelMessage::System(_) => fail("Expected no system message")
    _ => ()
  }
}

///|
test "SystemPromptWhen::Never never applies system prompt" {
  let builder = DefaultContextBuilder::default()
  let input : @interfaces.ContextInput = {
    session_history: [],
    memory_context: [],
    skills: [],
    bootstrap: "Bootstrap",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "Hello",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 1000L,
    },
    system_prompt_config: Some({
      mode: @types.SystemPromptMode::Append,
      when: @types.SystemPromptWhen::Never,
      content: "Extra",
    }),
    is_first_message: true,
    context_files: @interfaces.ContextFiles::empty(),
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  // Only user message, no system message
  inspect(messages.length(), content="1")
}

// ============================================================
// ContextFiles（OpenClaw互換）テスト
// ============================================================

///|
test "DefaultContextBuilder includes SOUL.md in system prompt" {
  let builder = DefaultContextBuilder::default()
  let input : @interfaces.ContextInput = {
    session_history: [],
    memory_context: [],
    skills: [],
    bootstrap: "",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "Hello",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 1000L,
    },
    system_prompt_config: None,
    is_first_message: true,
    context_files: {
      soul: Some("Be helpful, honest, and harmless"),
      agents_handbook: None,
      tools_config: None,
      identity: None,
      user_context: None,
      heartbeat: None,
    },
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  match messages[0] {
    @types.ModelMessage::System(content) => {
      inspect(content.contains("Soul & Values"), content="true")
      inspect(content.contains("helpful, honest"), content="true")
    }
    _ => fail("Expected system message")
  }
}

///|
test "DefaultContextBuilder includes all context files" {
  let builder = DefaultContextBuilder::default()
  let input : @interfaces.ContextInput = {
    session_history: [],
    memory_context: [],
    skills: [],
    bootstrap: "Base instructions",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "Hello",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 1000L,
    },
    system_prompt_config: None,
    is_first_message: true,
    context_files: {
      soul: Some("Soul content"),
      agents_handbook: Some("Handbook content"),
      tools_config: Some("Tools content"),
      identity: Some("Identity content"),
      user_context: Some("User content"),
      heartbeat: None,
    },
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  match messages[0] {
    @types.ModelMessage::System(content) => {
      // 全セクションが含まれることを確認
      inspect(content.contains("Soul & Values"), content="true")
      inspect(content.contains("Identity"), content="true")
      inspect(content.contains("Base instructions"), content="true")
      inspect(content.contains("Workspace Handbook"), content="true")
      inspect(content.contains("Available Tools"), content="true") // ビルトインツールガイド
      inspect(content.contains("User's Tool Preferences"), content="true") // TOOLS.md
      inspect(content.contains("User Preferences"), content="true")
    }
    _ => fail("Expected system message")
  }
}

///|
test "ContextFiles::empty returns all None" {
  let files = @interfaces.ContextFiles::empty()
  inspect(files.soul, content="None")
  inspect(files.agents_handbook, content="None")
  inspect(files.tools_config, content="None")
  inspect(files.identity, content="None")
  inspect(files.user_context, content="None")
  inspect(files.heartbeat, content="None")
}

///|
test "ContextFiles::has_soul returns true when soul is set" {
  let files : @interfaces.ContextFiles = {
    soul: Some("Be helpful"),
    agents_handbook: None,
    tools_config: None,
    identity: None,
    user_context: None,
    heartbeat: None,
  }
  inspect(files.has_soul(), content="true")
}

///|
test "ContextFiles::has_soul returns false when soul is empty" {
  let files : @interfaces.ContextFiles = {
    soul: Some("   "),
    agents_handbook: None,
    tools_config: None,
    identity: None,
    user_context: None,
    heartbeat: None,
  }
  inspect(files.has_soul(), content="false")
}

///|
test "ContextFiles::has_soul returns false when soul is None" {
  let files : @interfaces.ContextFiles = {
    soul: None,
    agents_handbook: None,
    tools_config: None,
    identity: None,
    user_context: None,
    heartbeat: None,
  }
  inspect(files.has_soul(), content="false")
}

///|
/// 文字列内でターゲットの位置を検索（テスト用ヘルパー）
fn find_position(haystack : String, needle : String) -> Int {
  let h_len = haystack.length()
  let n_len = needle.length()
  if n_len == 0 || n_len > h_len {
    return -1
  }
  for i in 0..<(h_len - n_len + 1) {
    let slice = haystack[i:i + n_len].to_string() catch { _ => continue }
    if slice == needle {
      return i
    }
  }
  -1
}

///|
test "DefaultContextBuilder context_files ordering in system prompt" {
  // システムプロンプト内の順序: SOUL → IDENTITY → bootstrap → AGENTS → TOOLS → USER
  let builder = DefaultContextBuilder::default()
  let input : @interfaces.ContextInput = {
    session_history: [],
    memory_context: [],
    skills: [],
    bootstrap: "BOOTSTRAP_MARKER",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "Hello",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 1000L,
    },
    system_prompt_config: None,
    is_first_message: true,
    context_files: {
      soul: Some("SOUL_MARKER"),
      agents_handbook: Some("AGENTS_MARKER"),
      tools_config: Some("TOOLS_MARKER"),
      identity: Some("IDENTITY_MARKER"),
      user_context: Some("USER_MARKER"),
      heartbeat: None,
    },
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  match messages[0] {
    @types.ModelMessage::System(content) => {
      // 各マーカーの位置を取得
      let soul_pos = find_position(content, "SOUL_MARKER")
      let identity_pos = find_position(content, "IDENTITY_MARKER")
      let bootstrap_pos = find_position(content, "BOOTSTRAP_MARKER")
      let agents_pos = find_position(content, "AGENTS_MARKER")
      let tools_pos = find_position(content, "TOOLS_MARKER")
      let user_pos = find_position(content, "USER_MARKER")
      // 順序を検証: SOUL < IDENTITY < BOOTSTRAP < AGENTS < TOOLS < USER
      inspect(soul_pos < identity_pos, content="true")
      inspect(identity_pos < bootstrap_pos, content="true")
      inspect(bootstrap_pos < agents_pos, content="true")
      inspect(agents_pos < tools_pos, content="true")
      inspect(tools_pos < user_pos, content="true")
    }
    _ => fail("Expected system message")
  }
}

///|
test "SystemPromptMode::Replace preserves context_files sections" {
  // Replace モードでもSOUL/IDENTITYは維持される
  let builder = DefaultContextBuilder::default()
  let input : @interfaces.ContextInput = {
    session_history: [],
    memory_context: [],
    skills: [],
    bootstrap: "Original bootstrap",
    current_message: @types.InboundEnvelope::{
      channel: "http",
      chat_id: "test",
      sender_id: "user1",
      sender_name: "User",
      content: "Hello",
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: 1000L,
    },
    system_prompt_config: Some({
      mode: @types.SystemPromptMode::Replace,
      when: @types.SystemPromptWhen::Always,
      content: "Custom replacement",
    }),
    is_first_message: true,
    context_files: {
      soul: Some("Soul values"),
      agents_handbook: Some("Handbook content"),
      tools_config: None,
      identity: Some("Identity info"),
      user_context: None,
      heartbeat: None,
    },
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  match messages[0] {
    @types.ModelMessage::System(content) => {
      // Replace時、bootstrapは含まれないがcontext_filesは含まれる
      inspect(content.contains("Original bootstrap"), content="false")
      inspect(content.contains("Custom replacement"), content="true")
      inspect(content.contains("Soul values"), content="true")
      inspect(content.contains("Identity info"), content="true")
      inspect(content.contains("Handbook content"), content="true")
    }
    _ => fail("Expected system message")
  }
}
