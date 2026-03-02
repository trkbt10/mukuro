///|
/// Memoryツール - 長期記憶の読み書き
/// 定義と実装を統合

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn memory_tool() -> @types.ToolDefinition {
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
        "key": string_param("Memory key (for get/set/delete). Use descriptive keys like 'user_name', 'user_preferences'"),
        "value": { "description": "Value to store (for set action)" },
        "query": string_param("Search query (for search action). Use to find user information by keyword"),
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
/// メモリストア（インメモリ実装）
pub struct MemoryStore {
  data : Map[String, Json]
  metadata : Map[String, Int64]
}

///|
pub fn MemoryStore::new() -> MemoryStore {
  { data: {}, metadata: {} }
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
pub fn execute_memory(store : MemoryStore, args : Json) -> ToolExecutionResult {
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
        Some(value) => ToolExecutionResult::success({ "key": key, "value": value })
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
      ToolExecutionResult::success({ "key": key, "stored": true })
    }
    "delete" => {
      let key = match get_string_arg(args, "key") {
        Some(k) => k
        None => return ToolExecutionResult::error("Missing key argument")
      }
      let deleted = store.delete(key)
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
