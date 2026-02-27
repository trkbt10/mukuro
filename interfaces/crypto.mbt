///|
/// Cryptographic utilities for security

///|
/// Constant-time string comparison to prevent timing attacks.
/// Always compares the full length of both strings regardless of where they differ.
pub fn constant_time_compare(a : String, b : String) -> Bool {
  let a_bytes = @utf8.encode(a)
  let b_bytes = @utf8.encode(b)
  if a_bytes.length() != b_bytes.length() {
    // Still do work to avoid leaking length difference timing
    let mut _dummy = 0
    for i in 0..<a_bytes.length() {
      _dummy = _dummy.lxor(a_bytes[i].to_int())
    }
    return false
  }
  let mut result = 0
  for i in 0..<a_bytes.length() {
    result = result.lor(a_bytes[i].to_int().lxor(b_bytes[i].to_int()))
  }
  result == 0
}
