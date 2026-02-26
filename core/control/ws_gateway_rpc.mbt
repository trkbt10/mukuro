///|
/// WebSocket Gateway RPC Utilities
/// JSON-RPC parsing and response building

///|
/// Convert GatewayState to string
fn gateway_state_to_string(state : @interfaces.GatewayState) -> String {
  match state {
    @interfaces.GatewayState::Stopped => "stopped"
    @interfaces.GatewayState::Starting => "starting"
    @interfaces.GatewayState::Running => "running"
    @interfaces.GatewayState::Stopping => "stopping"
    @interfaces.GatewayState::Error(_) => "error"
  }
}

///|
/// Parse JSON-RPC request from string
fn parse_jsonrpc_request(message : String) -> @interfaces.JsonRpcRequest? {
  let json : Json = @json.parse(message) catch { _ => return None }
  match json {
    Object(obj) => {
      let rpc_method = match obj.get("method") {
        Some(String(m)) => m
        _ => return None
      }
      let id : Int? = match obj.get("id") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
      let params : Json? = obj.get("params")
      Some({ jsonrpc: "2.0", rpc_method, params, id })
    }
    _ => None
  }
}

///|
/// Build JSON-RPC success response
pub fn jsonrpc_success_response(id : Int?, result : Json) -> String {
  let response : Map[String, Json] = { "jsonrpc": "2.0", "result": result }
  match id {
    Some(i) => response["id"] = Json::number(i.to_double())
    None => ()
  }
  Json::object(response).stringify()
}

///|
/// Build JSON-RPC error response
pub fn jsonrpc_error_response(
  id : Int?,
  code : Int,
  message : String,
  data : Json?,
) -> String {
  let error : Map[String, Json] = {
    "code": Json::number(code.to_double()),
    "message": Json::string(message),
  }
  match data {
    Some(d) => error["data"] = d
    None => ()
  }
  let response : Map[String, Json] = {
    "jsonrpc": "2.0",
    "error": Json::object(error),
  }
  match id {
    Some(i) => response["id"] = Json::number(i.to_double())
    None => ()
  }
  Json::object(response).stringify()
}
