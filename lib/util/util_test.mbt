///|
test "IdGenerator sequential" {
  let gen = IdGenerator::new("item")
  inspect!(gen.next(), content="item_1")
  inspect!(gen.next(), content="item_2")
  inspect!(gen.current(), content="3")
}

///|
test "IdGenerator reset" {
  let gen = IdGenerator::new("x")
  let _ = gen.next()
  gen.reset()
  inspect!(gen.next(), content="x_1")
}

///|
test "pop_first empty" {
  let arr : Array[Int] = []
  inspect!(pop_first(arr), content="None")
}

///|
test "pop_first removes first" {
  let arr = [1, 2, 3]
  inspect!(pop_first(arr), content="Some(1)")
  inspect!(arr.length(), content="2")
  inspect!(arr[0], content="2")
}

///|
test "ConnectionState lifecycle" {
  let state = ConnectionState::new()
  inspect!(state.is_connected(), content="false")
  state.connect()
  inspect!(state.is_connected(), content="true")
  state.disconnect()
  inspect!(state.is_connected(), content="false")
}

///|
test "TimestampGenerator sequential" {
  let ts = TimestampGenerator::new(start=100L)
  inspect!(ts.next(), content="100")
  inspect!(ts.next(), content="101")
  inspect!(ts.current(), content="102")
}

///|
test "get_string extracts value" {
  let params : Json = { "name": "test", "count": 5 }
  inspect!(get_string(Some(params), "name"), content="Some(\"test\")")
  inspect!(get_string(Some(params), "missing"), content="None")
}

///|
test "get_int extracts value" {
  let params : Json = { "count": Json::number(42.0) }
  inspect!(get_int(Some(params), "count"), content="Some(42)")
}

///|
test "get_bool extracts value" {
  let params : Json = { "enabled": Json::boolean(true) }
  inspect!(get_bool(Some(params), "enabled"), content="Some(true)")
}

///|
test "get_string_array extracts array" {
  let params : Json = { "tags": Json::array([Json::string("a"), Json::string("b")]) }
  match get_string_array(Some(params), "tags") {
    Some(arr) => inspect!(arr.length(), content="2")
    None => fail!("Expected array")
  }
}
