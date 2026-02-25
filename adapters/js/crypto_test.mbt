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

// =============================================================================
// Base64 Tests
// =============================================================================

///|
test "base64_encode empty data" {
  let crypto = JsCrypto::new()
  let result = @interfaces.Crypto::base64_encode(crypto, data=Bytes::new(0))
  inspect(result, content="")
}

///|
test "base64_encode single byte" {
  let crypto = JsCrypto::new()
  let data = make_bytes_1(b'A')
  let result = @interfaces.Crypto::base64_encode(crypto, data~)
  inspect(result, content="QQ==")
}

///|
test "base64_encode two bytes" {
  let crypto = JsCrypto::new()
  let data = make_bytes_2(b'A', b'B')
  let result = @interfaces.Crypto::base64_encode(crypto, data~)
  inspect(result, content="QUI=")
}

///|
test "base64_encode three bytes" {
  let crypto = JsCrypto::new()
  let data = make_bytes_3(b'A', b'B', b'C')
  let result = @interfaces.Crypto::base64_encode(crypto, data~)
  inspect(result, content="QUJD")
}

///|
test "base64_encode 'Hello'" {
  let crypto = JsCrypto::new()
  let data = string_to_bytes("Hello")
  let result = @interfaces.Crypto::base64_encode(crypto, data~)
  inspect(result, content="SGVsbG8=")
}

///|
test "base64_encode 'Hello, World!'" {
  let crypto = JsCrypto::new()
  let data = string_to_bytes("Hello, World!")
  let result = @interfaces.Crypto::base64_encode(crypto, data~)
  inspect(result, content="SGVsbG8sIFdvcmxkIQ==")
}

///|
test "base64_decode empty string" {
  let crypto = JsCrypto::new()
  let result = @interfaces.Crypto::base64_decode(crypto, data="") catch {
    _ => Bytes::new(0)
  }
  inspect(result.length(), content="0")
}

///|
test "base64_decode 'QQ=='" {
  let crypto = JsCrypto::new()
  let result = @interfaces.Crypto::base64_decode(crypto, data="QQ==") catch {
    _ => Bytes::new(0)
  }
  inspect(result.length(), content="1")
  inspect(result[0].to_int(), content="65") // 'A'
}

///|
test "base64_decode 'SGVsbG8='" {
  let crypto = JsCrypto::new()
  let result = @interfaces.Crypto::base64_decode(crypto, data="SGVsbG8=") catch {
    _ => return
  }
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
  let crypto = JsCrypto::new()
  let result = @interfaces.Crypto::base64_decode(
    crypto,
    data="SGVsbG8sIFdvcmxkIQ==",
  ) catch {
    _ => return
  }
  let sb = StringBuilder::new()
  for b in result {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  inspect(sb.to_string(), content="Hello, World!")
}

///|
test "base64 roundtrip" {
  let crypto = JsCrypto::new()
  let original = "The quick brown fox jumps over the lazy dog"
  let data = string_to_bytes(original)
  let encoded = @interfaces.Crypto::base64_encode(crypto, data~)
  let decoded = @interfaces.Crypto::base64_decode(crypto, data=encoded) catch {
    _ => return
  }
  inspect(decoded.length(), content="43")
  let sb = StringBuilder::new()
  for b in decoded {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  inspect(sb.to_string(), content="The quick brown fox jumps over the lazy dog")
}

///|
test "base64_decode invalid length" {
  let crypto = JsCrypto::new()
  let mut got_error = false
  let _ = @interfaces.Crypto::base64_decode(crypto, data="ABC") catch {
    @crypto.CryptoError::DecodeError(_) => {
      got_error = true
      Bytes::new(0)
    }
    _ => Bytes::new(0)
  }
  if not(got_error) {
    fail("Expected DecodeError for invalid length")
  }
}

// =============================================================================
// SHA-256 Tests
// =============================================================================

///|
test "sha256 empty input" {
  let crypto = JsCrypto::new()
  let result = @interfaces.Crypto::sha256(crypto, data=Bytes::new(0))
  inspect(result.length(), content="32")
  // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  inspect(
    @crypto.bytes_to_hex(result),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256 'abc'" {
  let crypto = JsCrypto::new()
  let data = make_bytes_3(b'a', b'b', b'c')
  let result = @interfaces.Crypto::sha256(crypto, data~)
  // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  inspect(
    @crypto.bytes_to_hex(result),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 'hello'" {
  let crypto = JsCrypto::new()
  let data = string_to_bytes("hello")
  let result = @interfaces.Crypto::sha256(crypto, data~)
  // SHA-256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
  inspect(
    @crypto.bytes_to_hex(result),
    content="2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
  )
}

///|
test "sha256 long message" {
  let crypto = JsCrypto::new()
  let data = string_to_bytes("The quick brown fox jumps over the lazy dog")
  let result = @interfaces.Crypto::sha256(crypto, data~)
  // SHA-256("The quick brown fox jumps over the lazy dog") = d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592
  inspect(
    @crypto.bytes_to_hex(result),
    content="d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592",
  )
}

///|
test "sha256 multiple blocks" {
  let crypto = JsCrypto::new()
  // Create data > 64 bytes to test multiple block processing
  let data = string_to_bytes(
    "This is a longer message that spans multiple SHA-256 blocks for testing purposes.",
  )
  let result = @interfaces.Crypto::sha256(crypto, data~)
  inspect(result.length(), content="32")
  // The hash should be deterministic
  let hash1 = @crypto.bytes_to_hex(result)
  let result2 = @interfaces.Crypto::sha256(crypto, data~)
  let hash2 = @crypto.bytes_to_hex(result2)
  inspect(hash1 == hash2, content="true")
}

// =============================================================================
// HMAC-SHA256 Tests
// =============================================================================

///|
test "hmac_sha256 basic" {
  let crypto = JsCrypto::new()
  let key = string_to_bytes("key")
  let data = string_to_bytes("The quick brown fox jumps over the lazy dog")
  let result = @interfaces.Crypto::hmac_sha256(crypto, key~, data~)
  inspect(result.length(), content="32")
  // HMAC-SHA256(key, "The quick brown fox jumps over the lazy dog") = f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8
  inspect(
    @crypto.bytes_to_hex(result),
    content="f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8",
  )
}

///|
test "hmac_sha256 empty key and data" {
  let crypto = JsCrypto::new()
  let result = @interfaces.Crypto::hmac_sha256(
    crypto,
    key=Bytes::new(0),
    data=Bytes::new(0),
  )
  inspect(result.length(), content="32")
  // HMAC-SHA256("", "") = b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad
  inspect(
    @crypto.bytes_to_hex(result),
    content="b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad",
  )
}

///|
test "hmac_sha256 long key" {
  let crypto = JsCrypto::new()
  // Key longer than 64 bytes
  let key = string_to_bytes(
    "This is a very long key that is longer than 64 bytes to test key hashing behavior",
  )
  let data = string_to_bytes("data")
  let result = @interfaces.Crypto::hmac_sha256(crypto, key~, data~)
  inspect(result.length(), content="32")
  // Result should be deterministic
  let result2 = @interfaces.Crypto::hmac_sha256(crypto, key~, data~)
  inspect(
    @crypto.bytes_to_hex(result) == @crypto.bytes_to_hex(result2),
    content="true",
  )
}

// =============================================================================
// Hex helper tests
// =============================================================================

///|
test "@crypto.bytes_to_hex empty" {
  let result = @crypto.bytes_to_hex(Bytes::new(0))
  inspect(result, content="")
}

///|
test "@crypto.bytes_to_hex single byte" {
  let data = make_bytes_1(b'\xff')
  let result = @crypto.bytes_to_hex(data)
  inspect(result, content="ff")
}

///|
test "@crypto.bytes_to_hex multiple bytes" {
  let data = make_bytes_4(b'\xde', b'\xad', b'\xbe', b'\xef')
  let result = @crypto.bytes_to_hex(data)
  inspect(result, content="deadbeef")
}
