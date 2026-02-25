///|
/// JS Crypto 実装
/// core/crypto の共通実装を使用

///|
pub struct JsCrypto {
  _placeholder : Unit
}

///|
pub fn JsCrypto::new() -> JsCrypto {
  { _placeholder: () }
}

///|
pub impl @interfaces.Crypto for JsCrypto with sha256(self, data~) {
  ignore(self)
  @crypto.sha256_hash(data)
}

///|
pub impl @interfaces.Crypto for JsCrypto with hmac_sha256(self, key~, data~) {
  ignore(self)
  @crypto.hmac_sha256(key, data)
}

///|
pub impl @interfaces.Crypto for JsCrypto with base64_encode(self, data~) {
  ignore(self)
  @crypto.base64_encode(data)
}

///|
pub impl @interfaces.Crypto for JsCrypto with base64_decode(self, data~) {
  ignore(self)
  @crypto.base64_decode(data)
}
