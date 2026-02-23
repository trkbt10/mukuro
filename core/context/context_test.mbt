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
  }
  let messages = @interfaces.ContextBuilder::build(builder, input)
  // システムメッセージ + ユーザーメッセージ
  inspect(messages.length(), content="2")
}

///|
test "DefaultContextBuilder includes history" {
  let builder = DefaultContextBuilder::default()
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
