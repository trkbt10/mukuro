///|
/// Crypto Tests

// =============================================================================
// Helper functions
// =============================================================================

///|
fn string_to_bytes(s : String) -> Bytes {
  let arr : FixedArray[Byte] = FixedArray::make(s.length(), b'\x00')
  for i, c in s {
    arr[i] = c.to_int().to_byte()
  }
  Bytes::from_array(arr[:])
}

///|
fn make_bytes_1(b0 : Byte) -> Bytes {
  let arr : FixedArray[Byte] = FixedArray::make(1, b'\x00')
  arr[0] = b0
  Bytes::from_array(arr[:])
}

///|
fn make_bytes_2(b0 : Byte, b1 : Byte) -> Bytes {
  let arr : FixedArray[Byte] = FixedArray::make(2, b'\x00')
  arr[0] = b0
  arr[1] = b1
  Bytes::from_array(arr[:])
}

///|
fn make_bytes_3(b0 : Byte, b1 : Byte, b2 : Byte) -> Bytes {
  let arr : FixedArray[Byte] = FixedArray::make(3, b'\x00')
  arr[0] = b0
  arr[1] = b1
  arr[2] = b2
  Bytes::from_array(arr[:])
}

///|
fn make_bytes_4(b0 : Byte, b1 : Byte, b2 : Byte, b3 : Byte) -> Bytes {
  let arr : FixedArray[Byte] = FixedArray::make(4, b'\x00')
  arr[0] = b0
  arr[1] = b1
  arr[2] = b2
  arr[3] = b3
  Bytes::from_array(arr[:])
}

///|
fn base64_encode(data~ : Bytes) -> String {
  @base64.encode(data, padding=true)
}

///|
fn base64_decode(data~ : String) -> Bytes raise {
  @base64.decode(data, ignore_whitespace=false)
}

///|
fn sha256(data~ : Bytes) -> Bytes {
  Bytes::from_array(@xcrypto.sha256(data)[:])
}

///|
fn hmac_sha256(key~ : Bytes, data~ : Bytes) -> Bytes {
  Bytes::from_array(@xcrypto.hmac(@xcrypto.SHA256::new(), key, data)[:])
}

// =============================================================================
// Base64 Tests
// =============================================================================

///|
test "base64_encode empty data" {
  let result = base64_encode(data=Bytes::new(0))
  inspect(result, content="")
}

///|
test "base64_encode single byte" {
  let data = make_bytes_1(b'A')
  let result = base64_encode(data~)
  inspect(result, content="QQ==")
}

///|
test "base64_encode two bytes" {
  let data = make_bytes_2(b'A', b'B')
  let result = base64_encode(data~)
  inspect(result, content="QUI=")
}

///|
test "base64_encode three bytes" {
  let data = make_bytes_3(b'A', b'B', b'C')
  let result = base64_encode(data~)
  inspect(result, content="QUJD")
}

///|
test "base64_encode 'Hello'" {
  let data = string_to_bytes("Hello")
  let result = base64_encode(data~)
  inspect(result, content="SGVsbG8=")
}

///|
test "base64_encode 'Hello, World!'" {
  let data = string_to_bytes("Hello, World!")
  let result = base64_encode(data~)
  inspect(result, content="SGVsbG8sIFdvcmxkIQ==")
}

///|
test "base64_decode empty string" {
  let result = base64_decode(data="") catch { _ => Bytes::new(0) }
  inspect(result.length(), content="0")
}

///|
test "base64_decode 'QQ=='" {
  let result = base64_decode(data="QQ==") catch { _ => Bytes::new(0) }
  inspect(result.length(), content="1")
  inspect(result[0].to_int(), content="65") // 'A'
}

///|
test "base64_decode 'SGVsbG8='" {
  let result = base64_decode(data="SGVsbG8=") catch { _ => return }
  inspect(result.length(), content="5")
  // Verify it decodes to "Hello"
  let sb = StringBuilder::new()
  for b in result {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  inspect(sb.to_string(), content="Hello")
}

///|
test "base64_decode 'SGVsbG8sIFdvcmxkIQ=='" {
  let result = base64_decode(data="SGVsbG8sIFdvcmxkIQ==") catch { _ => return }
  let sb = StringBuilder::new()
  for b in result {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  inspect(sb.to_string(), content="Hello, World!")
}

///|
test "base64 roundtrip" {
  let original = "The quick brown fox jumps over the lazy dog"
  let data = string_to_bytes(original)
  let encoded = base64_encode(data~)
  let decoded = base64_decode(data=encoded) catch { _ => return }
  inspect(decoded.length(), content="43")
  let sb = StringBuilder::new()
  for b in decoded {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  inspect(sb.to_string(), content="The quick brown fox jumps over the lazy dog")
}

///|
test "base64_decode invalid length" {
  let mut got_error = false
  let _ = base64_decode(data="ABC") catch {
    _ => {
      got_error = true
      Bytes::new(0)
    }
  }
  if not(got_error) {
    fail("Expected error for invalid length")
  }
}

// =============================================================================
// SHA-256 Tests
// =============================================================================

///|
test "sha256 empty input" {
  let result = sha256(data=Bytes::new(0))
  inspect(result.length(), content="32")
  // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  inspect(
    @xcrypto.bytes_to_hex_string(result),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256 'abc'" {
  let data = make_bytes_3(b'a', b'b', b'c')
  let result = sha256(data~)
  // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  inspect(
    @xcrypto.bytes_to_hex_string(result),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 'hello'" {
  let data = string_to_bytes("hello")
  let result = sha256(data~)
  // SHA-256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
  inspect(
    @xcrypto.bytes_to_hex_string(result),
    content="2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
  )
}

///|
test "sha256 long message" {
  let data = string_to_bytes("The quick brown fox jumps over the lazy dog")
  let result = sha256(data~)
  // SHA-256("The quick brown fox jumps over the lazy dog") = d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592
  inspect(
    @xcrypto.bytes_to_hex_string(result),
    content="d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592",
  )
}

///|
test "sha256 multiple blocks" {
  // Create data > 64 bytes to test multiple block processing
  let data = string_to_bytes(
    "This is a longer message that spans multiple SHA-256 blocks for testing purposes.",
  )
  let result = sha256(data~)
  inspect(result.length(), content="32")
  // The hash should be deterministic
  let hash1 = @xcrypto.bytes_to_hex_string(result)
  let result2 = sha256(data~)
  let hash2 = @xcrypto.bytes_to_hex_string(result2)
  inspect(hash1 == hash2, content="true")
}

// =============================================================================
// HMAC-SHA256 Tests
// =============================================================================

///|
test "hmac_sha256 basic" {
  let key = string_to_bytes("key")
  let data = string_to_bytes("The quick brown fox jumps over the lazy dog")
  let result = hmac_sha256(key~, data~)
  inspect(result.length(), content="32")
  // HMAC-SHA256(key, "The quick brown fox jumps over the lazy dog") = f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8
  inspect(
    @xcrypto.bytes_to_hex_string(result),
    content="f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8",
  )
}

///|
test "hmac_sha256 empty key and data" {
  let result = hmac_sha256(key=Bytes::new(0), data=Bytes::new(0))
  inspect(result.length(), content="32")
  // HMAC-SHA256("", "") = b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad
  inspect(
    @xcrypto.bytes_to_hex_string(result),
    content="b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad",
  )
}

///|
test "hmac_sha256 long key" {
  // Key longer than 64 bytes
  let key = string_to_bytes(
    "This is a very long key that is longer than 64 bytes to test key hashing behavior",
  )
  let data = string_to_bytes("data")
  let result = hmac_sha256(key~, data~)
  inspect(result.length(), content="32")
  // Result should be deterministic
  let result2 = hmac_sha256(key~, data~)
  inspect(
    @xcrypto.bytes_to_hex_string(result) ==
    @xcrypto.bytes_to_hex_string(result2),
    content="true",
  )
}

// =============================================================================
// Hex helper tests
// =============================================================================

///|
test "@xcrypto.bytes_to_hex_string empty" {
  let result = @xcrypto.bytes_to_hex_string(Bytes::new(0))
  inspect(result, content="")
}

///|
test "@xcrypto.bytes_to_hex_string single byte" {
  let data = make_bytes_1(b'\xff')
  let result = @xcrypto.bytes_to_hex_string(data)
  inspect(result, content="ff")
}

///|
test "@xcrypto.bytes_to_hex_string multiple bytes" {
  let data = make_bytes_4(b'\xde', b'\xad', b'\xbe', b'\xef')
  let result = @xcrypto.bytes_to_hex_string(data)
  inspect(result, content="deadbeef")
}
