///|
test "rpc_connect_response returns success" {
  let response = rpc_connect_response(Some(1))
  let has_error = match response.error {
    Some(_) => true
    None => false
  }
  inspect!(has_error, content="false")
}

///|
test "rpc_disconnect_response returns success" {
  let response = rpc_disconnect_response(Some(2))
  let has_error = match response.error {
    Some(_) => true
    None => false
  }
  inspect!(has_error, content="false")
}

///|
test "rpc_method_not_found returns error" {
  let response = rpc_method_not_found("unknown", Some(3))
  match response.error {
    Some(err) => inspect!(err.code, content="-32601")
    None => fail!("Expected error")
  }
}

///|
test "rpc_invalid_params returns error" {
  let response = rpc_invalid_params("Missing field", Some(4))
  match response.error {
    Some(err) => inspect!(err.code, content="-32602")
    None => fail!("Expected error")
  }
}
