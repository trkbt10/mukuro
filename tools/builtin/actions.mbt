///|
/// Builtin Plugin Actions
/// API actions that can be invoked via dashboard/API

///|
/// Action definition
pub(all) struct ActionDefinition {
  /// Action name (e.g., "memory.list")
  name : String
  /// Action handler
  handler : (Json) -> @api.ApiResponse
}

///|
/// Get all memory-related API actions
pub fn get_memory_actions(store : @tools.MemoryStore) -> Array[ActionDefinition] {
  [
    {
      name: "memory.list",
      handler: fn(_params) {
        let keys = store.keys()
        let entries : Array[Json] = []
        for key in keys {
          let entry : Map[String, Json] = {}
          entry["key"] = Json::string(key)
          match store.get(key) {
            Some(value) => entry["value"] = value
            None => ()
          }
          entries.push(Json::object(entry))
        }
        @api.json_response(200, {
          "data": { "entries": Json::array(entries), "count": keys.length() },
        })
      },
    },
    {
      name: "memory.get",
      handler: fn(params) {
        let key = match params {
          { "key": String(k), .. } => k
          _ =>
            return @api.error_response(
              400, "bad_request", "Missing 'key' parameter",
            )
        }
        match store.get(key) {
          Some(value) =>
            @api.json_response(200, { "data": { "key": key, "value": value } })
          None =>
            @api.error_response(404, "not_found", "Key '\{key}' not found")
        }
      },
    },
    {
      name: "memory.set",
      handler: fn(params) {
        let key = match params {
          { "key": String(k), .. } => k
          _ =>
            return @api.error_response(
              400, "bad_request", "Missing 'key' parameter",
            )
        }
        let value = match params {
          { "value": v, .. } => v
          _ =>
            return @api.error_response(
              400, "bad_request", "Missing 'value' parameter",
            )
        }
        store.set(key, value)
        @api.json_response(200, { "ok": true, "key": key })
      },
    },
    {
      name: "memory.delete",
      handler: fn(params) {
        let key = match params {
          { "key": String(k), .. } => k
          _ =>
            return @api.error_response(
              400, "bad_request", "Missing 'key' parameter",
            )
        }
        let deleted = store.delete(key)
        @api.json_response(200, { "ok": true, "deleted": deleted })
      },
    },
    {
      name: "memory.clear",
      handler: fn(_params) {
        store.clear()
        @api.json_response(200, { "ok": true })
      },
    },
  ]
}

///|
/// Get all builtin actions
pub fn get_all_builtin_actions(store : @tools.MemoryStore) -> Array[ActionDefinition] {
  // Currently only memory actions, but extensible
  get_memory_actions(store)
}
