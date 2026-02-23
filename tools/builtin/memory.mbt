///|
/// メモリツール - 長期記憶の読み書き

///|
/// メモリストア（インメモリ実装）
pub struct MemoryStore {
  /// キー・バリューストア
  data : Map[String, Json]
  /// メタデータ（作成日時など）
  metadata : Map[String, Int64]
}

///|
/// MemoryStoreを新規作成
pub fn MemoryStore::new() -> MemoryStore {
  { data: {}, metadata: {} }
}

///|
/// メモリに保存
pub fn MemoryStore::set(self : MemoryStore, key : String, value : Json) -> Unit {
  self.data[key] = value
  self.metadata[key] = get_current_time_ms()
}

///|
/// メモリから取得
pub fn MemoryStore::get(self : MemoryStore, key : String) -> Json? {
  self.data.get(key)
}

///|
/// メモリから削除
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
/// 全キーを取得
pub fn MemoryStore::keys(self : MemoryStore) -> Array[String] {
  let result : Array[String] = []
  for key, _ in self.data {
    result.push(key)
  }
  result
}

///|
/// メモリをクリア
pub fn MemoryStore::clear(self : MemoryStore) -> Unit {
  self.data.clear()
  self.metadata.clear()
}

///|
/// キーの存在確認
pub fn MemoryStore::has(self : MemoryStore, key : String) -> Bool {
  self.data.contains(key)
}

///|
/// メモリツール定義
pub fn memory_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="memory",
    description="Store and retrieve information in long-term memory",
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
          "description": "Action to perform on memory",
        },
        "key": string_param("Memory key (for get/set/delete)", false),
        "value": { "description": "Value to store (for set action)" },
        "query": string_param("Search query (for search action)", false),
      },
      ["action"],
    ),
  )
}

///|
/// メモリツールを実行
pub fn execute_memory_tool(
  store : MemoryStore,
  args : Json,
) -> ToolExecutionResult {
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
      // 簡易検索（キー名に含まれるか）
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
