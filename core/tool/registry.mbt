///|
/// ツールエントリ（定義と実行者のペア）
struct ToolEntry {
  definition : @types.ToolDefinition
  executor : &@interfaces.ToolExecutor
}

///|
/// インメモリツールレジストリ
pub struct InMemoryToolRegistry {
  tools : Map[String, ToolEntry]
}

///|
/// InMemoryToolRegistryを新規作成
pub fn InMemoryToolRegistry::new() -> InMemoryToolRegistry {
  { tools: {} }
}

///|
/// ToolRegistry実装
pub impl @interfaces.ToolRegistry for InMemoryToolRegistry with register(
  self,
  definition,
  executor,
) {
  self.tools[definition.name] = { definition, executor }
}

///|
pub impl @interfaces.ToolRegistry for InMemoryToolRegistry with list_definitions(
  self,
) {
  let result : Array[@types.ToolDefinition] = []
  for entry in self.tools.values() {
    result.push(entry.definition)
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
) -> @types.ToolDefinition? {
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
