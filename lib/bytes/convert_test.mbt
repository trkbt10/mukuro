///|
test "decode_utf8 - ASCII string" {
  let bytes = @utf8.encode("hello")
  let result = @bytes.decode_utf8(bytes[:])
  inspect(result, content="Some(\"hello\")")
}

///|
test "decode_utf8 - Japanese text" {
  let bytes = @utf8.encode("こんにちは")
  let result = @bytes.decode_utf8(bytes[:])
  inspect(result, content="Some(\"こんにちは\")")
}

///|
test "decode_utf8 - emoji" {
  let bytes = @utf8.encode("🎉🚀")
  let result = @bytes.decode_utf8(bytes[:])
  inspect(result, content="Some(\"🎉🚀\")")
}

///|
test "decode_utf8 - empty" {
  let bytes = Bytes::new(0)
  let result = @bytes.decode_utf8(bytes[:])
  inspect(result, content="Some(\"\")")
}

///|
test "decode_utf8 - invalid UTF-8 returns None" {
  // 不正なUTF-8シーケンス: 0xFF は有効なUTF-8先頭バイトではない
  let bytes = Bytes::from_iter([b'\xFF', b'\xFE'].iter())
  let result = @bytes.decode_utf8(bytes[:])
  inspect(result, content="None")
}

///|
test "decode_utf8 - partial buffer (BytesView slice)" {
  let bytes = @utf8.encode("hello world")
  // 先頭5バイトだけデコード ("hello")
  let result = @bytes.decode_utf8(bytes[:5])
  inspect(result, content="Some(\"hello\")")
}

///|
test "decode_utf8_or - success" {
  let bytes = @utf8.encode("test")
  let result = @bytes.decode_utf8_or(bytes[:], default="fallback")
  inspect(result, content="test")
}

///|
test "decode_utf8_or - fallback on invalid" {
  let bytes = Bytes::from_iter([b'\xFF', b'\xFE'].iter())
  let result = @bytes.decode_utf8_or(bytes[:], default="fallback")
  inspect(result, content="fallback")
}

///|
test "encode_utf8 - ASCII" {
  let bytes = @bytes.encode_utf8("abc")
  inspect(bytes.length(), content="3")
  inspect(bytes[0], content="b'\\x61'")
  inspect(bytes[1], content="b'\\x62'")
  inspect(bytes[2], content="b'\\x63'")
}

///|
test "encode_utf8 - Japanese" {
  let bytes = @bytes.encode_utf8("あ")
  // "あ" = U+3042 = 0xE3 0x81 0x82 in UTF-8
  inspect(bytes.length(), content="3")
  inspect(bytes[0], content="b'\\xE3'")
  inspect(bytes[1], content="b'\\x81'")
  inspect(bytes[2], content="b'\\x82'")
}

///|
test "encode_utf8 - round trip" {
  let original = "Hello, 世界! 🌍"
  let encoded = @bytes.encode_utf8(original)
  let decoded = @bytes.decode_utf8(encoded[:])
  inspect(decoded, content="Some(\"Hello, 世界! 🌍\")")
}

///|
test "to_utf8_cstring - ASCII with null terminator" {
  let result = @bytes.to_utf8_cstring("abc")
  inspect(result.length(), content="4")
  inspect(result[0], content="b'\\x61'")
  inspect(result[1], content="b'\\x62'")
  inspect(result[2], content="b'\\x63'")
  inspect(result[3], content="b'\\x00'")
}

///|
test "to_utf8_cstring - empty string" {
  let result = @bytes.to_utf8_cstring("")
  inspect(result.length(), content="1")
  inspect(result[0], content="b'\\x00'")
}

///|
test "to_utf8_cstring - Japanese with null terminator" {
  let result = @bytes.to_utf8_cstring("あ")
  // "あ" = 3 bytes UTF-8 + 1 null = 4 bytes
  inspect(result.length(), content="4")
  inspect(result[0], content="b'\\xE3'")
  inspect(result[1], content="b'\\x81'")
  inspect(result[2], content="b'\\x82'")
  inspect(result[3], content="b'\\x00'")
}

///|
test "to_utf8_cstring - content matches encode_utf8 plus null" {
  let s = "test_path/file.txt"
  let cstr = @bytes.to_utf8_cstring(s)
  let utf8 = @bytes.encode_utf8(s)
  // CString は UTF-8 + null 終端
  inspect(cstr.length(), content=(utf8.length() + 1).to_string())
  for i in 0..<utf8.length() {
    assert_eq(cstr[i], utf8[i])
  }
  assert_eq(cstr[utf8.length()], b'\x00')
}
