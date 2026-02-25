///|
test "parse_root_object success" {
  let result = parse_root_object("{\"key\": \"value\"}")
  inspect(result is Ok(_), content="true")
}

///|
test "parse_root_object invalid json" {
  let result = parse_root_object("not json")
  inspect(result is Err(_), content="true")
}

///|
test "parse_root_object not an object" {
  let result = parse_root_object("[1,2,3]")
  inspect(result is Err(_), content="true")
}

///|
test "required_string_field success" {
  let obj : Map[String, Json] = { "name": "Alice" }
  let result = required_string_field(obj, "name")
  match result {
    Ok(v) => inspect(v, content="Alice")
    Err(_) => ()
  }
}

///|
test "required_string_field missing" {
  let obj : Map[String, Json] = {}
  let result = required_string_field(obj, "name")
  inspect(result is Err(_), content="true")
}

///|
test "required_int_field success" {
  let obj : Map[String, Json] = { "count": Json::number(42) }
  let result = required_int_field(obj, "count")
  match result {
    Ok(v) => inspect(v, content="42")
    Err(_) => ()
  }
}

///|
test "int64_field_or_default with value" {
  let obj : Map[String, Json] = { "timeout": Json::number(120000) }
  let result = int64_field_or_default(obj, "timeout", 0L)
  match result {
    Ok(v) => inspect(v, content="120000")
    Err(_) => ()
  }
}

///|
test "int64_field_or_default without value" {
  let obj : Map[String, Json] = {}
  let result = int64_field_or_default(obj, "timeout", 60000L)
  match result {
    Ok(v) => inspect(v, content="60000")
    Err(_) => ()
  }
}

///|
test "double_field_or_default with value" {
  let obj : Map[String, Json] = { "rate": Json::number(0.75) }
  let result = double_field_or_default(obj, "rate", 1.0)
  match result {
    Ok(v) => inspect(v, content="0.75")
    Err(_) => ()
  }
}

///|
test "optional_string_field with value" {
  let obj : Map[String, Json] = { "name": "Bob" }
  let result = optional_string_field(obj, "name")
  match result {
    Ok(v) => inspect(v, content="Some(\"Bob\")")
    Err(_) => ()
  }
}

///|
test "optional_string_field null" {
  let obj : Map[String, Json] = { "name": Json::null() }
  let result = optional_string_field(obj, "name")
  match result {
    Ok(v) => inspect(v, content="None")
    Err(_) => ()
  }
}

///|
test "optional_string_field missing" {
  let obj : Map[String, Json] = {}
  let result = optional_string_field(obj, "name")
  match result {
    Ok(v) => inspect(v, content="None")
    Err(_) => ()
  }
}

///|
test "optional_int_field with value" {
  let obj : Map[String, Json] = { "count": Json::number(10) }
  let result = optional_int_field(obj, "count")
  match result {
    Ok(v) => inspect(v, content="Some(10)")
    Err(_) => ()
  }
}

///|
test "optional_bool_field true" {
  let obj : Map[String, Json] = { "enabled": Json::boolean(true) }
  let result = optional_bool_field(obj, "enabled")
  match result {
    Ok(v) => inspect(v, content="Some(true)")
    Err(_) => ()
  }
}

///|
test "optional_bool_field false" {
  let obj : Map[String, Json] = { "enabled": Json::boolean(false) }
  let result = optional_bool_field(obj, "enabled")
  match result {
    Ok(v) => inspect(v, content="Some(false)")
    Err(_) => ()
  }
}

///|
test "string_array_field_or_default with values" {
  let obj : Map[String, Json] = { "tags": ["a", "b", "c"] }
  let result = string_array_field_or_default(obj, "tags")
  match result {
    Ok(v) => inspect(v, content="[\"a\", \"b\", \"c\"]")
    Err(_) => ()
  }
}

///|
test "string_array_field_or_default empty" {
  let obj : Map[String, Json] = {}
  let result = string_array_field_or_default(obj, "tags")
  match result {
    Ok(v) => inspect(v, content="[]")
    Err(_) => ()
  }
}
