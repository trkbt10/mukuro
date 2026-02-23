///|
/// スキルローダー
/// スキル定義の読み込みと管理を担当
pub struct SkillLoader {
  /// 登録されたスキル
  skills : Map[String, @interfaces.SkillDefinition]
}

///|
/// SkillLoaderを新規作成
pub fn SkillLoader::new() -> SkillLoader {
  { skills: {} }
}

///|
/// スキルを登録
pub fn SkillLoader::register(
  self : SkillLoader,
  skill : @interfaces.SkillDefinition,
) -> Unit {
  self.skills[skill.name] = skill
}

///|
/// スキルを取得
pub fn SkillLoader::get(
  self : SkillLoader,
  name : String,
) -> @interfaces.SkillDefinition? {
  self.skills.get(name)
}

///|
/// 全スキルを取得
pub fn SkillLoader::list(
  self : SkillLoader,
) -> Array[@interfaces.SkillDefinition] {
  self.skills.values().collect()
}

///|
/// スキルが存在するか確認
pub fn SkillLoader::has(self : SkillLoader, name : String) -> Bool {
  self.skills.contains(name)
}

///|
/// スキルを削除
pub fn SkillLoader::remove(self : SkillLoader, name : String) -> Bool {
  match self.skills.get(name) {
    Some(_) => {
      self.skills.remove(name)
      true
    }
    None => false
  }
}

///|
/// スキル定義を作成するヘルパー
pub fn create_skill(
  name~ : String,
  description~ : String,
  instructions~ : String,
) -> @interfaces.SkillDefinition {
  { name, description, instructions }
}

///|
/// JSONからスキル定義をパース（簡易版）
pub fn parse_skill_from_json(json : Json) -> @interfaces.SkillDefinition? {
  match json {
    { "name": String(name), "description": String(description), .. } => {
      let instructions = match json {
        { "instructions": String(inst), .. } => inst
        _ => ""
      }
      Some({ name, description, instructions })
    }
    _ => None
  }
}

///|
/// 複数のスキル定義をJSONからパース
pub fn parse_skills_from_json(
  json : Json,
) -> Array[@interfaces.SkillDefinition] {
  let result : Array[@interfaces.SkillDefinition] = []
  match json {
    Array(skills) =>
      for skill_json in skills {
        match parse_skill_from_json(skill_json) {
          Some(skill) => result.push(skill)
          None => ()
        }
      }
    _ => ()
  }
  result
}
