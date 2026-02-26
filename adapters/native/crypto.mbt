///|
/// Native Random実装
pub struct NativeRandom {
  mut seed : Int64
}

///|
pub fn NativeRandom::new() -> NativeRandom {
  { seed: c_time() }
}

///|
fn NativeRandom::next_int(self : NativeRandom) -> Int {
  self.seed = (self.seed * 1103515245L + 12345L) & 0x7FFFFFFFL
  self.seed.to_int()
}

///|
pub impl @interfaces.Random for NativeRandom with random(self) {
  let n = self.next_int()
  n.to_double() / 2147483647.0
}

///|
pub impl @interfaces.Random for NativeRandom with random_int(self, min~, max~) {
  let r = self.random()
  let range = (max - min + 1).to_double()
  min + (r * range).to_int()
}

///|
pub impl @interfaces.Random for NativeRandom with random_bytes(self, length~) {
  Bytes::makei(length, fn(i) {
    ignore(i)
    let n = self.next_int()
    n.land(0xFF).to_byte()
  })
}

///|
pub impl @interfaces.Random for NativeRandom with uuid_v4(self) {
  let sb = StringBuilder::new()
  for i in 0..<32 {
    if i == 8 || i == 12 || i == 16 || i == 20 {
      sb.write_char('-')
    }
    let n = self.next_int() & 0xF
    sb.write_char(hex_char(n))
  }
  sb.to_string()
}

///|
fn hex_char(n : Int) -> Char {
  if n < 10 {
    (48 + n).unsafe_to_char()
  } else {
    (97 + n - 10).unsafe_to_char()
  }
}
