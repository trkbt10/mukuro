///|
/// Tests for ffi_time.mbt - Time-related FFI functions

///|
test "c_time returns positive Unix epoch seconds" {
  let now = @native.c_time()
  // Should be after 2020-01-01 (epoch 1577836800)
  @native.ffi_assert_true(now > 1577836800L)
}

///|
test "c_time increases monotonically" {
  let t1 = @native.c_time()
  @native.c_sleep_ms(10)
  let t2 = @native.c_time()
  @native.ffi_assert_true(t2 >= t1)
}

///|
test "c_gmtime parses epoch correctly" {
  // 2024-01-15 00:00:00 UTC = 1705276800
  let epoch : Int64 = 1705276800L
  let buf = Bytes::new(12)
  let result = @native.c_gmtime(epoch, buf)
  assert_eq(result, 0)
  // Read year (little-endian Int32 at offset 0)
  let year = buf[0].to_int() |
    (buf[1].to_int() << 8) |
    (buf[2].to_int() << 16) |
    (buf[3].to_int() << 24)
  // Read month (little-endian Int32 at offset 4)
  let month = buf[4].to_int() |
    (buf[5].to_int() << 8) |
    (buf[6].to_int() << 16) |
    (buf[7].to_int() << 24)
  // Read day (little-endian Int32 at offset 8)
  let day = buf[8].to_int() |
    (buf[9].to_int() << 8) |
    (buf[10].to_int() << 16) |
    (buf[11].to_int() << 24)
  assert_eq(year, 2024)
  assert_eq(month, 1)
  assert_eq(day, 15)
}

///|
test "c_gmtime handles epoch zero" {
  let epoch : Int64 = 0L
  let buf = Bytes::new(12)
  let result = @native.c_gmtime(epoch, buf)
  assert_eq(result, 0)
  let year = buf[0].to_int() |
    (buf[1].to_int() << 8) |
    (buf[2].to_int() << 16) |
    (buf[3].to_int() << 24)
  let month = buf[4].to_int() |
    (buf[5].to_int() << 8) |
    (buf[6].to_int() << 16) |
    (buf[7].to_int() << 24)
  let day = buf[8].to_int() |
    (buf[9].to_int() << 8) |
    (buf[10].to_int() << 16) |
    (buf[11].to_int() << 24)
  assert_eq(year, 1970)
  assert_eq(month, 1)
  assert_eq(day, 1)
}
