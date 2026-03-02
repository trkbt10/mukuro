///|
/// file_utils read/write round-trip tests

///|
test "read_file_bytes returns empty bytes for empty file" {
  let path = "/tmp/mukuro_test_empty_bytes"
  native_write_file_text(path, "") catch {
    _ => fail("write failed")
  }
  let data = native_read_file_bytes(path) catch { _ => fail("read failed") }
  assert_eq(data.length(), 0)
  let _ = c_remove_bytes(string_to_utf8_cstring(path))
}

///|
test "read_file_bytes round-trip small data" {
  let path = "/tmp/mukuro_test_small_bytes"
  let original = Bytes::makei(256, fn(i) { i.to_byte() })
  native_write_file_bytes(path, original) catch {
    _ => fail("write failed")
  }
  let read_back = native_read_file_bytes(path) catch {
    _ => fail("read failed")
  }
  assert_eq(read_back.length(), 256)
  for i = 0; i < 256; i = i + 1 {
    assert_eq(read_back[i], original[i])
  }
  let _ = c_remove_bytes(string_to_utf8_cstring(path))
}

///|
test "read_file_bytes handles exactly one chunk (64KB)" {
  let path = "/tmp/mukuro_test_one_chunk_bytes"
  let size = 65536
  let original = Bytes::makei(size, fn(i) { (i % 251).to_byte() })
  native_write_file_bytes(path, original) catch {
    _ => fail("write failed")
  }
  let read_back = native_read_file_bytes(path) catch {
    _ => fail("read failed")
  }
  assert_eq(read_back.length(), size)
  // spot-check boundaries
  assert_eq(read_back[0], original[0])
  assert_eq(read_back[size - 1], original[size - 1])
  assert_eq(read_back[size / 2], original[size / 2])
  let _ = c_remove_bytes(string_to_utf8_cstring(path))
}

///|
test "read_file_bytes handles multi-chunk (>64KB)" {
  let path = "/tmp/mukuro_test_multi_chunk_bytes"
  // 100KB — requires 2 chunks (64KB + 36KB)
  let size = 102400
  let original = Bytes::makei(size, fn(i) { (i % 199).to_byte() })
  native_write_file_bytes(path, original) catch {
    _ => fail("write failed")
  }
  let read_back = native_read_file_bytes(path) catch {
    _ => fail("read failed")
  }
  assert_eq(read_back.length(), size)
  // verify first byte, last byte, and bytes around chunk boundary
  assert_eq(read_back[0], original[0])
  assert_eq(read_back[size - 1], original[size - 1])
  assert_eq(read_back[65535], original[65535])
  assert_eq(read_back[65536], original[65536])
  assert_eq(read_back[65537], original[65537])
  let _ = c_remove_bytes(string_to_utf8_cstring(path))
}

///|
test "read_file_bytes handles 3-chunk file (>128KB)" {
  let path = "/tmp/mukuro_test_three_chunk_bytes"
  // 150KB — requires 3 chunks (64KB + 64KB + 22KB)
  let size = 153600
  let original = Bytes::makei(size, fn(i) { (i % 173).to_byte() })
  native_write_file_bytes(path, original) catch {
    _ => fail("write failed")
  }
  let read_back = native_read_file_bytes(path) catch {
    _ => fail("read failed")
  }
  assert_eq(read_back.length(), size)
  // verify every 10000th byte
  let mut i = 0
  while i < size {
    assert_eq(read_back[i], original[i])
    i = i + 10000
  }
  let _ = c_remove_bytes(string_to_utf8_cstring(path))
}

///|
test "read_file_bytes raises FileNotFound for missing file" {
  let result : Result[Bytes, _] = try? native_read_file_bytes(
    "/tmp/mukuro_test_nonexistent_file_xyz",
  )
  assert_true(result is Err(_))
}

///|
test "write and read text round-trip" {
  let path = "/tmp/mukuro_test_text_roundtrip"
  let content = "こんにちは世界\nHello World\n🎉"
  native_write_file_text(path, content) catch {
    _ => fail("write failed")
  }
  let read_back = native_read_file_text(path) catch { _ => fail("read failed") }
  assert_eq(read_back, content)
  let _ = c_remove_bytes(string_to_utf8_cstring(path))
}

///|
test "append text adds to existing file" {
  let path = "/tmp/mukuro_test_append"
  native_write_file_text(path, "first\n") catch {
    _ => fail("write failed")
  }
  native_append_file_text(path, "second\n") catch {
    _ => fail("append failed")
  }
  let read_back = native_read_file_text(path) catch { _ => fail("read failed") }
  assert_eq(read_back, "first\nsecond\n")
  let _ = c_remove_bytes(string_to_utf8_cstring(path))
}
