///|
test "rpc_get_params with object params" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "key": "value" }),
    id=Some(1),
  )
  let params = rpc_get_params(request)
  inspect(params is Some(_), content="true")
}

///|
test "rpc_get_params with null params" {
  let request = JsonRpcRequest::new(rpc_method="test", params=None, id=Some(1))
  let params = rpc_get_params(request)
  inspect(params is None, content="true")
}

///|
test "rpc_require_string success" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "name": "Alice" }),
    id=Some(1),
  )
  let result = rpc_require_string(request, "name")
  inspect(result is Ok(_), content="true")
  match result {
    Ok(v) =>
      inspect(
        v,
        content=(
          #|Alice
        ),
      )
    Err(_) => ()
  }
}

///|
test "rpc_require_string missing" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "other": "value" }),
    id=Some(1),
  )
  let result = rpc_require_string(request, "name")
  inspect(result is Err(_), content="true")
}

///|
test "rpc_require_string wrong type" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "name": Json::number(123) }),
    id=Some(1),
  )
  let result = rpc_require_string(request, "name")
  inspect(result is Err(_), content="true")
}

///|
test "rpc_require_int success" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "count": Json::number(42) }),
    id=Some(1),
  )
  let result = rpc_require_int(request, "count")
  inspect(result is Ok(_), content="true")
  match result {
    Ok(v) => inspect(v, content="42")
    Err(_) => ()
  }
}

///|
test "rpc_require_int64 success" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "timestamp": Json::number(1234567890123.0) }),
    id=Some(1),
  )
  let result = rpc_require_int64(request, "timestamp")
  inspect(result is Ok(_), content="true")
}

///|
test "rpc_require_double success" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "rate": Json::number(0.75) }),
    id=Some(1),
  )
  let result = rpc_require_double(request, "rate")
  inspect(result is Ok(_), content="true")
  match result {
    Ok(v) => inspect(v, content="0.75")
    Err(_) => ()
  }
}

///|
test "rpc_require_bool success" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "enabled": Json::boolean(true) }),
    id=Some(1),
  )
  let result = rpc_require_bool(request, "enabled")
  inspect(result is Ok(_), content="true")
  match result {
    Ok(v) => inspect(v, content="true")
    Err(_) => ()
  }
}

///|
test "rpc_optional_string with value" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "name": "Bob" }),
    id=Some(1),
  )
  let result = rpc_optional_string(request, "name", "default")
  inspect(
    result,
    content=(
      #|Bob
    ),
  )
}

///|
test "rpc_optional_string without value" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "other": "value" }),
    id=Some(1),
  )
  let result = rpc_optional_string(request, "name", "default")
  inspect(
    result,
    content=(
      #|default
    ),
  )
}

///|
test "rpc_optional_int with value" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "limit": Json::number(100) }),
    id=Some(1),
  )
  let result = rpc_optional_int(request, "limit", 10)
  inspect(result, content="100")
}

///|
test "rpc_optional_int without value" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({}),
    id=Some(1),
  )
  let result = rpc_optional_int(request, "limit", 10)
  inspect(result, content="10")
}

///|
test "rpc_optional_double with value" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "rate": Json::number(1.5) }),
    id=Some(1),
  )
  let result = rpc_optional_double(request, "rate", 1.0)
  inspect(result, content="1.5")
}

///|
test "rpc_optional_bool with value" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "active": Json::boolean(false) }),
    id=Some(1),
  )
  let result = rpc_optional_bool(request, "active", true)
  inspect(result, content="false")
}

///|
test "rpc_string_or_none with value" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "id": "abc123" }),
    id=Some(1),
  )
  let result = rpc_string_or_none(request, "id")
  inspect(result, content="Some(\"abc123\")")
}

///|
test "rpc_string_or_none without value" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({}),
    id=Some(1),
  )
  let result = rpc_string_or_none(request, "id")
  inspect(result, content="None")
}

///|
test "rpc_int_or_none with value" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "page": Json::number(5) }),
    id=Some(1),
  )
  let result = rpc_int_or_none(request, "page")
  inspect(result, content="Some(5)")
}

///|
test "rpc_string_array with values" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "tags": ["a", "b", "c"] }),
    id=Some(1),
  )
  let result = rpc_string_array(request, "tags")
  inspect(result, content="[\"a\", \"b\", \"c\"]")
}

///|
test "rpc_string_array empty" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({}),
    id=Some(1),
  )
  let result = rpc_string_array(request, "tags")
  inspect(result, content="[]")
}

///|
test "rpc_double_array with values" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({
      "values": [Json::number(1.0), Json::number(2.5), Json::number(3.0)],
    }),
    id=Some(1),
  )
  let result = rpc_double_array(request, "values")
  inspect(result.length(), content="3")
}

///|
test "rpc_object_or_none with object" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({ "config": { "key": "value" } }),
    id=Some(1),
  )
  let result = rpc_object_or_none(request, "config")
  inspect(result is Some(_), content="true")
}

///|
test "rpc_object_or_none without object" {
  let request = JsonRpcRequest::new(
    rpc_method="test",
    params=Some({}),
    id=Some(1),
  )
  let result = rpc_object_or_none(request, "config")
  inspect(result, content="None")
}
