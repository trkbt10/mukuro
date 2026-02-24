///|
/// コンテキスト構築オプション
pub(all) struct ContextOptions {
  /// システムプロンプトにスキル情報を含めるか
  include_skills : Bool
  /// システムプロンプトにメモリ情報を含めるか
  include_memory : Bool
  /// 最大コンテキストトークン数
  max_context_tokens : Int
}

///|
/// デフォルトのコンテキストオプション
pub fn ContextOptions::default() -> ContextOptions {
  { include_skills: true, include_memory: true, max_context_tokens: 100000 }
}

///|
/// デフォルトのコンテキストビルダー
pub struct DefaultContextBuilder {
  options : ContextOptions
}

///|
/// DefaultContextBuilderを新規作成
pub fn DefaultContextBuilder::new(
  options~ : ContextOptions,
) -> DefaultContextBuilder {
  { options, }
}

///|
/// デフォルト設定でDefaultContextBuilderを作成
pub fn DefaultContextBuilder::default() -> DefaultContextBuilder {
  { options: ContextOptions::default() }
}

///|
/// ContextBuilder実装
pub impl @interfaces.ContextBuilder for DefaultContextBuilder with build(
  self,
  input,
) {
  let messages : Array[@types.ModelMessage] = []
  // 1. システムプロンプトを構築
  let system_prompt = self.build_system_prompt(input)
  if system_prompt.length() > 0 {
    messages.push(@types.ModelMessage::System(system_prompt))
  }
  // 2. 履歴を追加
  for msg in input.session_history {
    messages.push(msg)
  }
  // 3. 現在のメッセージを追加
  messages.push(
    @types.ModelMessage::User(content=input.current_message.content, name=None),
  )
  messages
}

///|
/// システムプロンプトを構築
fn DefaultContextBuilder::build_system_prompt(
  self : DefaultContextBuilder,
  input : @interfaces.ContextInput,
) -> String {
  let has_bootstrap = input.bootstrap.length() > 0
  let has_skills = self.options.include_skills && input.skills.length() > 0
  let has_memory = self.options.include_memory &&
    input.memory_context.length() > 0
  if not(has_bootstrap) && not(has_skills) && not(has_memory) {
    return ""
  }
  let parts : Array[String] = []
  // ブートストラップ指示
  if has_bootstrap {
    parts.push(input.bootstrap)
  }
  // スキル情報
  if has_skills {
    parts.push(format_skills(input.skills))
  }
  // メモリ情報
  if has_memory {
    parts.push(format_memory(input.memory_context))
  }
  join_parts(parts, "\n\n")
}

///|
/// スキル情報をフォーマット
fn format_skills(skills : Array[@interfaces.SkillDefinition]) -> String {
  if skills.length() == 0 {
    return ""
  }
  let buf = StringBuilder::new()
  buf.write_string("## Available Skills")
  for skill in skills {
    buf.write_string("\n### ")
    buf.write_string(skill.name)
    buf.write_string("\n")
    buf.write_string(skill.description)
    if skill.instructions.length() > 0 {
      buf.write_string("\n")
      buf.write_string(skill.instructions)
    }
  }
  buf.to_string()
}

///|
/// メモリ情報をフォーマット
fn format_memory(memory_context : Array[String]) -> String {
  if memory_context.length() == 0 {
    return ""
  }
  let buf = StringBuilder::new()
  buf.write_string("## Relevant Memory")
  for mem in memory_context {
    buf.write_string("\n- ")
    buf.write_string(mem)
  }
  buf.to_string()
}

///|
/// 文字列配列を結合
fn join_parts(parts : Array[String], separator : String) -> String {
  if parts.length() == 0 {
    return ""
  }
  let buf = StringBuilder::new()
  for i, part in parts {
    if i > 0 {
      buf.write_string(separator)
    }
    buf.write_string(part)
  }
  buf.to_string()
}

///|
/// InboundEnvelopeからModelMessageを生成
pub fn envelope_to_message(
  envelope : @types.InboundEnvelope,
) -> @types.ModelMessage {
  @types.ModelMessage::User(
    content=envelope.content,
    name=if envelope.sender_name.length() > 0 {
      Some(envelope.sender_name)
    } else {
      None
    },
  )
}
