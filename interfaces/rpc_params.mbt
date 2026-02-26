///|
/// JSON-RPC Parameter Extraction Utilities
/// Standardized parameter extraction for RPC handlers

///|
/// Extract parameters object from JSON-RPC request
pub fn rpc_get_params(request : JsonRpcRequest) -> Map[String, Json]? {
  match request.params {
    Some(Object(obj)) => Some(obj)
    _ => None
  }
}

///|
/// Extract required string parameter
/// Returns error response on failure
pub fn rpc_require_string(
  request : JsonRpcRequest,
  key : String,
) -> Result[String, JsonRpcResponse] {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(String(v)) => Ok(v)
        Some(_) =>
          Err(
            rpc_invalid_params(
              "Parameter '\{key}' must be a string",
              request.id,
            ),
          )
        None =>
          Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
      }
    _ => Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
  }
}

///|
/// Extract required int parameter
pub fn rpc_require_int(
  request : JsonRpcRequest,
  key : String,
) -> Result[Int, JsonRpcResponse] {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(v, ..)) => Ok(v.to_int())
        Some(_) =>
          Err(
            rpc_invalid_params(
              "Parameter '\{key}' must be a number",
              request.id,
            ),
          )
        None =>
          Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
      }
    _ => Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
  }
}

///|
/// Extract required int64 parameter
pub fn rpc_require_int64(
  request : JsonRpcRequest,
  key : String,
) -> Result[Int64, JsonRpcResponse] {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(v, ..)) => Ok(v.to_int64())
        Some(_) =>
          Err(
            rpc_invalid_params(
              "Parameter '\{key}' must be a number",
              request.id,
            ),
          )
        None =>
          Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
      }
    _ => Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
  }
}

///|
/// Extract required double parameter
pub fn rpc_require_double(
  request : JsonRpcRequest,
  key : String,
) -> Result[Double, JsonRpcResponse] {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(v, ..)) => Ok(v)
        Some(_) =>
          Err(
            rpc_invalid_params(
              "Parameter '\{key}' must be a number",
              request.id,
            ),
          )
        None =>
          Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
      }
    _ => Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
  }
}

///|
/// Extract required bool parameter
pub fn rpc_require_bool(
  request : JsonRpcRequest,
  key : String,
) -> Result[Bool, JsonRpcResponse] {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(True) => Ok(true)
        Some(False) => Ok(false)
        Some(_) =>
          Err(
            rpc_invalid_params(
              "Parameter '\{key}' must be a boolean",
              request.id,
            ),
          )
        None =>
          Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
      }
    _ => Err(rpc_invalid_params("Missing '\{key}' parameter", request.id))
  }
}

///|
/// Extract optional string parameter with default value
pub fn rpc_optional_string(
  request : JsonRpcRequest,
  key : String,
  default_value : String,
) -> String {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(String(v)) => v
        _ => default_value
      }
    _ => default_value
  }
}

///|
/// Extract optional int parameter with default value
pub fn rpc_optional_int(
  request : JsonRpcRequest,
  key : String,
  default_value : Int,
) -> Int {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(v, ..)) => v.to_int()
        _ => default_value
      }
    _ => default_value
  }
}

///|
/// Extract optional int64 parameter with default value
pub fn rpc_optional_int64(
  request : JsonRpcRequest,
  key : String,
  default_value : Int64,
) -> Int64 {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(v, ..)) => v.to_int64()
        _ => default_value
      }
    _ => default_value
  }
}

///|
/// Extract optional double parameter with default value
pub fn rpc_optional_double(
  request : JsonRpcRequest,
  key : String,
  default_value : Double,
) -> Double {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(v, ..)) => v
        _ => default_value
      }
    _ => default_value
  }
}

///|
/// Extract optional bool parameter with default value
pub fn rpc_optional_bool(
  request : JsonRpcRequest,
  key : String,
  default_value : Bool,
) -> Bool {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(True) => true
        Some(False) => false
        _ => default_value
      }
    _ => default_value
  }
}

///|
/// Extract optional string parameter (None if not present)
pub fn rpc_string_or_none(request : JsonRpcRequest, key : String) -> String? {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(String(v)) => Some(v)
        _ => None
      }
    _ => None
  }
}

///|
/// Extract optional int parameter (None if not present)
pub fn rpc_int_or_none(request : JsonRpcRequest, key : String) -> Int? {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(v, ..)) => Some(v.to_int())
        _ => None
      }
    _ => None
  }
}

///|
/// Extract optional int64 parameter (None if not present)
pub fn rpc_int64_or_none(request : JsonRpcRequest, key : String) -> Int64? {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(v, ..)) => Some(v.to_int64())
        _ => None
      }
    _ => None
  }
}

///|
/// Extract optional double parameter (None if not present)
pub fn rpc_double_or_none(request : JsonRpcRequest, key : String) -> Double? {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(v, ..)) => Some(v)
        _ => None
      }
    _ => None
  }
}

///|
/// Extract string array parameter (empty if not present)
pub fn rpc_string_array(
  request : JsonRpcRequest,
  key : String,
) -> Array[String] {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Array(arr)) => {
          let result : Array[String] = []
          for item in arr {
            match item {
              String(s) => result.push(s)
              _ => ()
            }
          }
          result
        }
        _ => []
      }
    _ => []
  }
}

///|
/// Extract double array parameter (empty if not present)
pub fn rpc_double_array(
  request : JsonRpcRequest,
  key : String,
) -> Array[Double] {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Array(arr)) => {
          let result : Array[Double] = []
          for item in arr {
            match item {
              Number(n, ..) => result.push(n)
              _ => ()
            }
          }
          result
        }
        _ => []
      }
    _ => []
  }
}

///|
/// Extract nested object parameter (None if not present)
pub fn rpc_object_or_none(
  request : JsonRpcRequest,
  key : String,
) -> Map[String, Json]? {
  match request.params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Object(o)) => Some(o)
        _ => None
      }
    _ => None
  }
}

// ============================================================================
// JSON Object Field Extraction Utilities
// Direct extraction from Map[String, Json] without RPC context
// ============================================================================

///|
/// Extract string from JSON object
pub fn json_string_field(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(v)) => Some(v)
    _ => None
  }
}

///|
/// Extract string with default value
pub fn json_string_or(
  obj : Map[String, Json],
  key : String,
  default : String,
) -> String {
  json_string_field(obj, key).unwrap_or(default)
}

///|
/// Extract int from JSON object
pub fn json_int_field(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

///|
/// Extract int with default value
pub fn json_int_or(obj : Map[String, Json], key : String, default : Int) -> Int {
  json_int_field(obj, key).unwrap_or(default)
}

///|
/// Extract int64 from JSON object
pub fn json_int64_field(obj : Map[String, Json], key : String) -> Int64? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.to_int64())
    _ => None
  }
}

///|
/// Extract int64 with default value
pub fn json_int64_or(
  obj : Map[String, Json],
  key : String,
  default : Int64,
) -> Int64 {
  json_int64_field(obj, key).unwrap_or(default)
}

///|
/// Extract double from JSON object
pub fn json_double_field(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
/// Extract double with default value
pub fn json_double_or(
  obj : Map[String, Json],
  key : String,
  default : Double,
) -> Double {
  json_double_field(obj, key).unwrap_or(default)
}

///|
/// Extract bool from JSON object
pub fn json_bool_field(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
/// Extract bool with default value
pub fn json_bool_or(
  obj : Map[String, Json],
  key : String,
  default : Bool,
) -> Bool {
  json_bool_field(obj, key).unwrap_or(default)
}

///|
/// Extract nested object from JSON object
pub fn json_object_field(
  obj : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match obj.get(key) {
    Some(Object(o)) => Some(o)
    _ => None
  }
}

///|
/// Extract array from JSON object
pub fn json_array_field(obj : Map[String, Json], key : String) -> Array[Json]? {
  match obj.get(key) {
    Some(Array(a)) => Some(a)
    _ => None
  }
}
