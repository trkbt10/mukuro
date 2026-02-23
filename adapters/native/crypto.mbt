///|
/// Native Crypto 実装（スタブ版）
/// 実際の暗号操作は将来の実装で追加

///|
pub(all) suberror CryptoError {
  HashError(String)
  EncodeError(String)
  DecodeError(String)
}

///|
pub struct NativeCrypto {
  _placeholder : Unit
}

///|
pub fn NativeCrypto::new() -> NativeCrypto {
  { _placeholder: () }
}

///|
pub impl @interfaces.Crypto for NativeCrypto with sha256(self, data~) {
  ignore(self)
  ignore(data)
  // 空の32バイトハッシュを返す（スタブ）
  Bytes::make(32, b'\x00')
}

///|
pub impl @interfaces.Crypto for NativeCrypto with hmac_sha256(self, key~, data~) {
  ignore(self)
  ignore(key)
  ignore(data)
  Bytes::make(32, b'\x00')
}

///|
pub impl @interfaces.Crypto for NativeCrypto with base64_encode(self, data~) {
  ignore(self)
  // 簡易Base64エンコード（スタブ）
  let sb = StringBuilder::new()
  for b in data {
    let n = b.to_int()
    sb.write_char(
      hex_char((n.reinterpret_as_uint() >> 4).land(0xFU).reinterpret_as_int()),
    )
    sb.write_char(hex_char(n & 0xF))
  }
  sb.to_string()
}

///|
pub impl @interfaces.Crypto for NativeCrypto with base64_decode(self, data~) {
  ignore(self)
  ignore(data)
  Bytes::new(0)
}

///|
fn hex_char(n : Int) -> Char {
  if n < 10 {
    (48 + n).unsafe_to_char()
  } else {
    (97 + n - 10).unsafe_to_char()
  }
}

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
  // Bytes::makei を使用
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
