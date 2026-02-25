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
pub fn rpc_method_not_found(method : String, id : Int?) -> JsonRpcResponse {
  JsonRpcResponse::error(
    code=jsonrpc_error_method_not_found(),
    message="Method not found: \{method}",
    id~,
  )
}

///|
pub fn rpc_invalid_params(message : String, id : Int?) -> JsonRpcResponse {
  JsonRpcResponse::error(
    code=jsonrpc_error_invalid_params(),
    message~,
    id~,
  )
}

///|
pub fn rpc_not_found(resource : String, id : Int?) -> JsonRpcResponse {
  JsonRpcResponse::error(
    code=jsonrpc_error_invalid_params(),
    message="\{resource} not found",
    id~,
  )
}
