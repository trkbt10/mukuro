///|
/// JSON-RPC Response Helpers
/// Standardized response builders for RPC handlers

///|
pub fn rpc_success_status(status : String, id : Int?) -> JsonRpcResponse {
  JsonRpcResponse::success(result={ "status": status }, id~)
}

///|
pub fn rpc_connect_response(id : Int?) -> JsonRpcResponse {
  rpc_success_status("connected", id)
}

///|
pub fn rpc_disconnect_response(id : Int?) -> JsonRpcResponse {
  rpc_success_status("disconnected", id)
}

///|
pub fn rpc_method_not_found(method_name : String, id : Int?) -> JsonRpcResponse {
  JsonRpcResponse::error(
    code=jsonrpc_error_method_not_found(),
    message="Method not found: \{method_name}",
    id~,
  )
}

///|
pub fn rpc_invalid_params(message : String, id : Int?) -> JsonRpcResponse {
  JsonRpcResponse::error(code=jsonrpc_error_invalid_params(), message~, id~)
}

///|
pub fn rpc_not_found(resource : String, id : Int?) -> JsonRpcResponse {
  JsonRpcResponse::error(
    code=jsonrpc_error_invalid_params(),
    message="\{resource} not found",
    id~,
  )
}

///|
/// Success response with array result
pub fn[T] rpc_success_array(
  key : String,
  items : Array[T],
  to_json : (T) -> Json,
  id : Int?,
) -> JsonRpcResponse {
  let arr : Array[Json] = []
  for item in items {
    arr.push(to_json(item))
  }
  let result : Map[String, Json] = {}
  result[key] = Json::array(arr)
  JsonRpcResponse::success(result=Json::object(result), id~)
}

///|
/// Success response with boolean result
pub fn rpc_success_bool(
  key : String,
  value : Bool,
  id : Int?,
) -> JsonRpcResponse {
  let result : Map[String, Json] = {}
  result[key] = Json::boolean(value)
  JsonRpcResponse::success(result=Json::object(result), id~)
}

///|
/// Status response for connectable plugins
pub fn rpc_status_response(
  is_connected : Bool,
  extra_fields : Map[String, Json],
  id : Int?,
) -> JsonRpcResponse {
  let result : Map[String, Json] = { "connected": is_connected }
  for k, v in extra_fields {
    result[k] = v
  }
  JsonRpcResponse::success(result=Json::object(result), id~)
}

///|
/// Null result response
pub fn rpc_null_result(key : String, id : Int?) -> JsonRpcResponse {
  let result : Map[String, Json] = {}
  result[key] = Json::null()
  JsonRpcResponse::success(result=Json::object(result), id~)
}

///|
/// Success response with int result
pub fn rpc_success_int(key : String, value : Int, id : Int?) -> JsonRpcResponse {
  let result : Map[String, Json] = {}
  result[key] = Json::number(value.to_double())
  JsonRpcResponse::success(result=Json::object(result), id~)
}

///|
/// Success response with double result
pub fn rpc_success_double(
  key : String,
  value : Double,
  id : Int?,
) -> JsonRpcResponse {
  let result : Map[String, Json] = {}
  result[key] = Json::number(value)
  JsonRpcResponse::success(result=Json::object(result), id~)
}

///|
/// Success response with simple OK status
pub fn rpc_ok(id : Int?) -> JsonRpcResponse {
  JsonRpcResponse::success(result={ "ok": true }, id~)
}
