// =============================================================================
// Url Parsing Tests
// =============================================================================

///|
test "parse simple path" {
  let url = parse("/ws/chat")
  assert_eq(url.path, "/ws/chat")
  assert_eq(url.query, None)
  assert_eq(url.fragment, None)
}

///|
test "parse path with query" {
  let url = parse("/ws/chat?id=123")
  assert_eq(url.path, "/ws/chat")
  assert_eq(url.query, Some("id=123"))
  assert_eq(url.fragment, None)
}

///|
test "parse path with fragment" {
  let url = parse("/ws/chat#section")
  assert_eq(url.path, "/ws/chat")
  assert_eq(url.query, None)
  assert_eq(url.fragment, Some("section"))
}

///|
test "parse full url" {
  let url = parse("/ws/chat?id=123&name=test#section")
  assert_eq(url.path, "/ws/chat")
  assert_eq(url.query, Some("id=123&name=test"))
  assert_eq(url.fragment, Some("section"))
}

///|
test "parse empty query" {
  let url = parse("/ws/chat?")
  assert_eq(url.path, "/ws/chat")
  assert_eq(url.query, Some(""))
  assert_eq(url.fragment, None)
}

///|
test "path extracts path only" {
  assert_eq(path("/ws/chat?id=123#section"), "/ws/chat")
}

///|
test "query_string extracts query" {
  assert_eq(query_string("/ws/chat?id=123"), Some("id=123"))
  assert_eq(query_string("/ws/chat"), None)
}

// =============================================================================
// Query Parameter Tests
// =============================================================================

///|
test "get_param single param" {
  let result = get_param("/ws/chat?chat_id=abc123", "chat_id")
  assert_eq(result, Some("abc123"))
}

///|
test "get_param multiple params first" {
  let result = get_param("/ws/chat?chat_id=abc&foo=bar", "chat_id")
  assert_eq(result, Some("abc"))
}

///|
test "get_param multiple params second" {
  let result = get_param("/ws/chat?chat_id=abc&foo=bar", "foo")
  assert_eq(result, Some("bar"))
}

///|
test "get_param not found" {
  let result = get_param("/ws/chat?chat_id=abc", "missing")
  assert_eq(result, None)
}

///|
test "get_param no query string" {
  let result = get_param("/ws/chat", "chat_id")
  assert_eq(result, None)
}

///|
test "get_param empty value" {
  let result = get_param("/ws/chat?chat_id=", "chat_id")
  assert_eq(result, Some(""))
}

///|
test "get_param url encoded value" {
  let result = get_param("/ws/chat?msg=hello%20world", "msg")
  assert_eq(result, Some("hello world"))
}

///|
test "get_param plus as space" {
  let result = get_param("/ws/chat?msg=hello+world", "msg")
  assert_eq(result, Some("hello world"))
}

///|
test "get_params returns map" {
  let params = get_params("/ws/chat?a=1&b=2&c=3")
  assert_eq(params.get("a"), Some("1"))
  assert_eq(params.get("b"), Some("2"))
  assert_eq(params.get("c"), Some("3"))
  assert_eq(params.get("d"), None)
}

///|
test "get_params empty query" {
  let params = get_params("/ws/chat")
  assert_eq(params.length(), 0)
}

///|
test "get_params with encoded values" {
  let params = get_params("/ws/chat?name=hello%20world&msg=a+b")
  assert_eq(params.get("name"), Some("hello world"))
  assert_eq(params.get("msg"), Some("a b"))
}

// =============================================================================
// Decode Tests
// =============================================================================

///|
test "decode simple" {
  assert_eq(decode("hello"), "hello")
}

///|
test "decode percent encoding" {
  assert_eq(decode("hello%20world"), "hello world")
}

///|
test "decode plus sign" {
  assert_eq(decode("hello+world"), "hello world")
}

///|
test "decode multiple encodings" {
  assert_eq(decode("%48%65%6C%6C%6F"), "Hello")
}

///|
test "decode mixed" {
  assert_eq(decode("a%20b+c%21d"), "a b c!d")
}

///|
test "decode incomplete percent" {
  assert_eq(decode("test%2"), "test%2")
}

///|
test "decode invalid hex" {
  assert_eq(decode("test%GGvalue"), "test%GGvalue")
}

// =============================================================================
// Encode Tests
// =============================================================================

///|
test "encode simple" {
  assert_eq(encode("hello"), "hello")
}

///|
test "encode space as plus" {
  assert_eq(encode("hello world"), "hello+world")
}

///|
test "encode special characters" {
  assert_eq(encode("a=b&c=d"), "a%3Db%26c%3Dd")
}

///|
test "encode unicode" {
  // Japanese "hello" = こんにちは
  let encoded = encode("日本語")
  // Should be percent-encoded UTF-8
  assert_eq(encoded.has_prefix("%"), true)
}

///|
test "encode preserves unreserved" {
  assert_eq(encode("abc-_.~123"), "abc-_.~123")
}

///|
test "encode roundtrip" {
  let original = "hello world & foo=bar"
  let encoded = encode(original)
  let decoded = decode(encoded)
  assert_eq(decoded, original)
}

// =============================================================================
// Backward Compatibility Tests
// =============================================================================

///|
test "parse_query_param alias works" {
  let result = parse_query_param("/ws/chat?id=123", "id")
  assert_eq(result, Some("123"))
}

///|
test "find_char alias works" {
  assert_eq(find_char("hello?world", '?'), 5)
  assert_eq(find_char("hello", '?'), -1)
}
