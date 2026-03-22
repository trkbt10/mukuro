///|
/// Memoryツール - 長期記憶の読み書き
/// 定義と実装を統合

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn memory_tool() -> @llm_types.ToolDefinition {
  make_tool_definition(
    name="memory",
    description="Store and retrieve user information and preferences in long-term memory. IMPORTANT: When users ask about themselves (name, preferences, history), ALWAYS search memory first before saying you don't know. When users share personal information, store it immediately.",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([
            Json::string("get"),
            Json::string("set"),
            Json::string("delete"),
            Json::string("list"),
            Json::string("search"),
          ]),
          "description": "Action to perform: 'search' to find user info, 'get' for exact key lookup, 'set' to store info, 'list' to see all keys, 'delete' to remove",
        },
        "key": string_param(
          "Memory key (for get/set/delete). Use descriptive keys like 'user_name', 'user_preferences'",
        ),
        "value": { "description": "Value to store (for set action)" },
        "query": string_param(
          "Search query (for search action). Use to find user information by keyword",
        ),
      },
      ["action"],
    ),
  )
}

///|
/// Memory tool settings schema for UI
pub fn memory_settings_schema() -> Json {
  build_settings_schema(
    title="Memory Settings",
    description="Configure memory store behavior",
    fields=[
      number_field(
        key="max_entries",
        label="Max Entries",
        description="Maximum number of entries to store",
        default_value=1000.0,
        min=Some(10.0),
        max=Some(100000.0),
      ),
      toggle_field(
        key="persist_to_disk",
        label="Persist to Disk",
        description="Save memory entries to disk for persistence across restarts",
        default_value=false,
      ),
    ],
  )
}

// =============================================================================
// Memory Store
// =============================================================================

///|
/// メモリストア（インメモリ + MEMORY.md ファイル永続化）
pub struct MemoryStore {
  data : Map[String, Json]
  metadata : Map[String, Int64]
  /// MEMORY.md ファイルパス（設定時に永続化が有効）
  mut persist_path : String?
}

///|
pub fn MemoryStore::new() -> MemoryStore {
  { data: {}, metadata: {}, persist_path: None }
}

///|
/// 永続化パスを設定して MEMORY.md を有効化
pub fn MemoryStore::set_persist_path(self : MemoryStore, path : String) -> Unit {
  self.persist_path = Some(path)
}

///|
/// MEMORY.md からデータをロード
pub fn MemoryStore::load_from_markdown(
  self : MemoryStore,
  content : String,
) -> Unit {
  // フォーマット: ## key\nvalue\n\n
  let mut current_key : String? = None
  let mut current_value = StringBuilder::new()
  let lines = content.split("\n")
  for line_view in lines {
    let line = line_view.to_string()
    if line.has_prefix("## ") {
      // 前のエントリを保存
      match current_key {
        Some(k) => {
          let v = current_value.to_string().trim(chars=" \t\r\n").to_string()
          if v.length() > 0 {
            let json_val : Json = @json.parse(v) catch { _ => Json::string(v) }
            self.data[k] = json_val
          }
        }
        None => ()
      }
      current_key = Some(line[3:].to_string().trim(chars=" \t\r\n").to_string())
      current_value = StringBuilder::new()
    } else {
      match current_key {
        Some(_) => {
          if current_value.to_string().length() > 0 {
            current_value.write_char('\n')
          }
          current_value.write_string(line)
        }
        None => ()
      }
    }
  }
  // 最後のエントリ
  match current_key {
    Some(k) => {
      let v = current_value.to_string().trim(chars=" \t\r\n").to_string()
      if v.length() > 0 {
        let json_val : Json = @json.parse(v) catch { _ => Json::string(v) }
        self.data[k] = json_val
      }
    }
    None => ()
  }
}

///|
/// MemoryStore の内容を MEMORY.md フォーマットで文字列化
pub fn MemoryStore::to_markdown(self : MemoryStore) -> String {
  let buf = StringBuilder::new()
  buf.write_string("# Long-term Memory\n\n")
  for key, value in self.data {
    buf.write_string("## \{key}\n")
    match value {
      String(s) => buf.write_string(s)
      _ => buf.write_string(value.stringify())
    }
    buf.write_string("\n\n")
  }
  buf.to_string()
}

///|
pub fn MemoryStore::set(self : MemoryStore, key : String, value : Json) -> Unit {
  self.data[key] = value
  self.metadata[key] = get_current_time_ms()
}

///|
pub fn MemoryStore::get(self : MemoryStore, key : String) -> Json? {
  self.data.get(key)
}

///|
pub fn MemoryStore::delete(self : MemoryStore, key : String) -> Bool {
  match self.data.get(key) {
    Some(_) => {
      self.data.remove(key)
      self.metadata.remove(key)
      true
    }
    None => false
  }
}

///|
pub fn MemoryStore::keys(self : MemoryStore) -> Array[String] {
  let result : Array[String] = []
  for key, _ in self.data {
    result.push(key)
  }
  result
}

///|
pub fn MemoryStore::clear(self : MemoryStore) -> Unit {
  self.data.clear()
  self.metadata.clear()
}

///|
pub fn MemoryStore::has(self : MemoryStore, key : String) -> Bool {
  self.data.contains(key)
}

// =============================================================================
// Tool Implementation
// =============================================================================

///|
/// Memoryツールエントリ
pub fn memory_entry() -> ToolEntry {
  {
    name: "memory",
    definition: memory_tool(),
    settings_schema: Some(memory_settings_schema()),
    execute: fn(ctx, args) { execute_memory(ctx.memory, args) },
  }
}

///|
fn execute_memory(store : MemoryStore, args : Json) -> ToolExecutionResult {
  let action = match get_string_arg(args, "action") {
    Some(a) => a
    None => return ToolExecutionResult::error("Missing action argument")
  }
  match action {
    "get" => {
      let key = match get_string_arg(args, "key") {
        Some(k) => k
        None => return ToolExecutionResult::error("Missing key argument")
      }
      match store.get(key) {
        Some(value) =>
          ToolExecutionResult::success({ "key": key, "value": value })
        None => ToolExecutionResult::error("Key not found: \{key}")
      }
    }
    "set" => {
      let key = match get_string_arg(args, "key") {
        Some(k) => k
        None => return ToolExecutionResult::error("Missing key argument")
      }
      let value = match args {
        { "value": v, .. } => v
        _ => return ToolExecutionResult::error("Missing value argument")
      }
      store.set(key, value)
      persist_memory(store)
      ToolExecutionResult::success({ "key": key, "stored": true })
    }
    "delete" => {
      let key = match get_string_arg(args, "key") {
        Some(k) => k
        None => return ToolExecutionResult::error("Missing key argument")
      }
      let deleted = store.delete(key)
      if deleted {
        persist_memory(store)
      }
      ToolExecutionResult::success({ "key": key, "deleted": deleted })
    }
    "list" => {
      let keys = store.keys()
      let keys_json : Array[Json] = keys.map(fn(k) { Json::string(k) })
      ToolExecutionResult::success({
        "keys": Json::array(keys_json),
        "count": keys.length(),
      })
    }
    "search" => {
      let query = match get_string_arg(args, "query") {
        Some(q) => q
        None => return ToolExecutionResult::error("Missing query argument")
      }
      let results : Array[Json] = []
      for key, value in store.data {
        if key.contains(query) {
          results.push({ "key": key, "value": value })
        }
      }
      ToolExecutionResult::success({
        "results": Json::array(results),
        "count": results.length(),
      })
    }
    _ => ToolExecutionResult::error("Unknown action: \{action}")
  }
}
