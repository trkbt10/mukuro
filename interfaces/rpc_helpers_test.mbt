///|
test "rpc_connect_response returns success" {
  let response = rpc_connect_response(Some(1))
  let has_error = match response.error {
    Some(_) => true
    None => false
  }
  inspect(has_error, content="false")
}

///|
test "rpc_disconnect_response returns success" {
  let response = rpc_disconnect_response(Some(2))
  let has_error = match response.error {
    Some(_) => true
    None => false
  }
  inspect(has_error, content="false")
}

///|
test "rpc_method_not_found returns error" {
  let response = rpc_method_not_found("unknown", Some(3))
  match response.error {
    Some(err) => inspect(err.code, content="-32601")
    None => fail("Expected error")
  }
}

///|
test "rpc_invalid_params returns error" {
  let response = rpc_invalid_params("Missing field", Some(4))
  match response.error {
    Some(err) => inspect(err.code, content="-32602")
    None => fail("Expected error")
  }
}

///|
test "rpc_success_array creates array response" {
  let items = [1, 2, 3]
  let response = rpc_success_array(
    "numbers",
    items,
    fn(n) { Json::number(n.to_double()) },
    Some(5),
  )
  inspect(response.error is None, content="true")
  inspect(response.result is Some(_), content="true")
}

///|
test "rpc_success_bool creates bool response" {
  let response = rpc_success_bool("deleted", true, Some(6))
  inspect(response.error is None, content="true")
  inspect(response.result is Some(_), content="true")
}

///|
test "rpc_status_response creates status response" {
  let extra : Map[String, Json] = { "count": Json::number(5) }
  let response = rpc_status_response(true, extra, Some(7))
  inspect(response.error is None, content="true")
}

///|
test "rpc_null_result creates null response" {
  let response = rpc_null_result("value", Some(8))
  inspect(response.error is None, content="true")
}

///|
test "rpc_ok creates simple ok response" {
  let response = rpc_ok(Some(9))
  inspect(response.error is None, content="true")
}
