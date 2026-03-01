///|
/// Shared test helpers for FFI tests

///|
pub fn ffi_assert_true(cond : Bool) -> Unit raise {
  if not(cond) {
    fail("Expected true but got false")
  }
}
