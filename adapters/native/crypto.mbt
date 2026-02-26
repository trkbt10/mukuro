///|
/// Native Random実装
pub struct NativeRandom {
  mut rand : @random.Rand
}

///|
pub fn NativeRandom::new() -> NativeRandom {
  { rand: @random.Rand::chacha8(seed=seed_material(c_time())) }
}

///|
pub impl @interfaces.Random for NativeRandom with random(self) {
  self.rand.double()
}

///|
pub impl @interfaces.Random for NativeRandom with random_int(self, min~, max~) {
  if min >= max {
    min
  } else {
    min + self.rand.int(limit=max - min + 1)
  }
}

///|
pub impl @interfaces.Random for NativeRandom with random_bytes(self, length~) {
  Bytes::makei(length, fn(i) {
    ignore(i)
    self.rand.uint(limit=256U).to_byte()
  })
}

///|
pub impl @interfaces.Random for NativeRandom with uuid_v4(self) {
  let bytes = self.random_bytes(length=16)
  @uuid.from_bytes(bytes).as_version(@uuid.V4).to_string() catch {
    _ => abort("unreachable: 16-byte UUID input is always valid")
  }
}

///|
fn seed_material(seed : Int64) -> Bytes {
  let base = seed.reinterpret_as_uint64()
  let bytes : FixedArray[Byte] = FixedArray::make(32, b'\x00')
  for i in 0..<32 {
    let shift = i % 8 * 8
    let mixed = (((base >> shift) & 0xFFUL).to_int() ^ (i * 73 + 41)) & 0xFF
    bytes[i] = mixed.to_byte()
  }
  Bytes::from_array(bytes[:])
}
