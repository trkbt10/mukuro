///|
/// コンテキスト構築オプション
pub(all) struct ContextOptions {
  /// システムプロンプトにスキル情報を含めるか
  include_skills : Bool
  /// システムプロンプトにメモリ情報を含めるか
  include_memory : Bool
  /// 最大コンテキストトークン数
  max_context_tokens : Int
  /// デフォルトのシステムプロンプトモード
  default_system_prompt_mode : @types.SystemPromptMode
  /// デフォルトのシステムプロンプト適用タイミング
  default_system_prompt_when : @types.SystemPromptWhen
}

///|
/// デフォルトのコンテキストオプション
pub fn ContextOptions::default() -> ContextOptions {
  {
    include_skills: true,
    include_memory: true,
    max_context_tokens: 100000,
    default_system_prompt_mode: @types.SystemPromptMode::Append,
    default_system_prompt_when: @types.SystemPromptWhen::Always,
  }
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
  // SystemPromptConfig からモードとタイミングを取得
  let (mode, when, custom_content) = match input.system_prompt_config {
    Some(config) => (config.mode, config.when, config.content)
    None =>
      (
        self.options.default_system_prompt_mode,
        self.options.default_system_prompt_when,
        "",
      )
  }
  // SystemPromptWhen による適用判定
  let should_apply = match when {
    @types.SystemPromptWhen::Always => true
    @types.SystemPromptWhen::First => input.is_first_message
    @types.SystemPromptWhen::Never => false
  }
  if not(should_apply) {
    return ""
  }
  let has_bootstrap = input.bootstrap.length() > 0
  let has_custom = custom_content.length() > 0
  let has_skills = self.options.include_skills && input.skills.length() > 0
  let has_memory = self.options.include_memory &&
    input.memory_context.length() > 0
  let has_context_files = input.context_files.has_soul() ||
    input.context_files.identity is Some(_) ||
    input.context_files.agents_handbook is Some(_) ||
    input.context_files.tools_config is Some(_) ||
    input.context_files.user_context is Some(_)
  if not(has_bootstrap) &&
    not(has_custom) &&
    not(has_skills) &&
    not(has_memory) &&
    not(has_context_files) {
    return ""
  }
  let parts : Array[String] = []
  // 1. SOUL.md - 性格・価値観（最優先）
  if input.context_files.has_soul() {
    match input.context_files.soul {
      Some(content) => parts.push(format_soul_section(content))
      None => ()
    }
  }
  // 2. IDENTITY.md - アイデンティティ
  match input.context_files.identity {
    Some(content) => parts.push(format_identity_section(content))
    None => ()
  }
  // 3. SystemPromptMode による適用方法
  match mode {
    @types.SystemPromptMode::Replace =>
      // Replace: カスタムコンテンツのみ使用
      if has_custom {
        parts.push(custom_content)
      }
    @types.SystemPromptMode::Append => {
      // Append: ブートストラップ + カスタムコンテンツ
      if has_bootstrap {
        parts.push(input.bootstrap)
      }
      if has_custom {
        parts.push(custom_content)
      }
    }
  }
  // 4. AGENTS.md - ワークスペース指針
  match input.context_files.agents_handbook {
    Some(content) => parts.push(format_handbook_section(content))
    None => ()
  }
  // 5. TOOLS.md - ツール設定
  match input.context_files.tools_config {
    Some(content) => parts.push(format_tools_section(content))
    None => ()
  }
  // 6. USER.md - ユーザー好み
  match input.context_files.user_context {
    Some(content) => parts.push(format_user_section(content))
    None => ()
  }
  // 7. スキル情報
  if has_skills {
    parts.push(format_skills(input.skills))
  }
  // 8. メモリ情報
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

// ============================================================
// コンテキストファイル（OpenClaw互換）フォーマット関数
// ============================================================

///|
/// SOUL.mdをフォーマット（性格・価値観定義）
fn format_soul_section(content : String) -> String {
  let buf = StringBuilder::new()
  buf.write_string("## Soul & Values\n")
  buf.write_string("Follow these core principles and values:\n\n")
  buf.write_string(content)
  buf.to_string()
}

///|
/// IDENTITY.mdをフォーマット（アイデンティティ）
fn format_identity_section(content : String) -> String {
  let buf = StringBuilder::new()
  buf.write_string("## Identity\n")
  buf.write_string(content)
  buf.to_string()
}

///|
/// AGENTS.mdをフォーマット（ワークスペースハンドブック）
fn format_handbook_section(content : String) -> String {
  let buf = StringBuilder::new()
  buf.write_string("## Workspace Handbook\n")
  buf.write_string(content)
  buf.to_string()
}

///|
/// TOOLS.mdをフォーマット（ツール設定）
fn format_tools_section(content : String) -> String {
  let buf = StringBuilder::new()
  buf.write_string("## Local Tools & Environment\n")
  buf.write_string(content)
  buf.to_string()
}

///|
/// USER.mdをフォーマット（ユーザー情報）
fn format_user_section(content : String) -> String {
  let buf = StringBuilder::new()
  buf.write_string("## User Preferences\n")
  buf.write_string(content)
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
