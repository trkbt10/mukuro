///|
/// ツールエントリ（定義と実行者のペア）
struct ToolEntry {
  definition : @llm_types.ToolDefinition
  executor : &@interfaces.ToolExecutor
}

///|
/// インメモリツールレジストリ
pub struct InMemoryToolRegistry {
  tools : Map[String, ToolEntry]
  mut definitions_cache : Array[@llm_types.ToolDefinition]?
}

///|
/// InMemoryToolRegistryを新規作成
pub fn InMemoryToolRegistry::new() -> InMemoryToolRegistry {
  { tools: {}, definitions_cache: None }
}

///|
/// ToolRegistry実装
pub impl @interfaces.ToolRegistry for InMemoryToolRegistry with register(
  self,
  definition,
  executor,
) {
  self.tools[definition.name] = { definition, executor }
  self.definitions_cache = None
}

///|
pub impl @interfaces.ToolRegistry for InMemoryToolRegistry with list_definitions(
  self,
) {
  let defs = match self.definitions_cache {
    Some(cached) => cached
    None => {
      let built : Array[@llm_types.ToolDefinition] = []
      for entry in self.tools.values() {
        built.push(entry.definition)
      }
      self.definitions_cache = Some(built)
      built
    }
  }
  let result : Array[@llm_types.ToolDefinition] = []
  for def in defs {
    result.push(def)
  }
  result
}

///|
pub impl @interfaces.ToolRegistry for InMemoryToolRegistry with get_executor(
  self,
  name,
) {
  match self.tools.get(name) {
    Some(entry) => Some(entry.executor)
    None => None
  }
}

///|
pub impl @interfaces.ToolRegistry for InMemoryToolRegistry with has_tool(
  self,
  name,
) {
  self.tools.contains(name)
}

///|
/// ツール定義を取得
pub fn InMemoryToolRegistry::get_definition(
  self : InMemoryToolRegistry,
  name : String,
) -> @llm_types.ToolDefinition? {
  match self.tools.get(name) {
    Some(entry) => Some(entry.definition)
    None => None
  }
}

///|
/// ツールを削除
pub fn InMemoryToolRegistry::remove(
  self : InMemoryToolRegistry,
  name : String,
) -> Bool {
  match self.tools.get(name) {
    Some(_) => {
      self.tools.remove(name)
      self.definitions_cache = None
      true
    }
    None => false
  }
}

///|
/// 登録されているツール数を取得
pub fn InMemoryToolRegistry::count(self : InMemoryToolRegistry) -> Int {
  self.tools.length()
}

///|
/// 全ツール名を取得
pub fn InMemoryToolRegistry::list_names(
  self : InMemoryToolRegistry,
) -> Array[String] {
  self.tools.keys().collect()
}
