///|
/// JS Crypto 実装
/// SHA-256, HMAC-SHA256, Base64 を純粋なMoonBitで実装
/// (Web Crypto APIを使用する場合は非同期版を別途実装可能)

///|
pub(all) suberror CryptoError {
  HashError(String)
  EncodeError(String)
  DecodeError(String)
}

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
  sha256_hash(data)
}

///|
pub impl @interfaces.Crypto for JsCrypto with hmac_sha256(self, key~, data~) {
  ignore(self)
  hmac_sha256_compute(key, data)
}

///|
pub impl @interfaces.Crypto for JsCrypto with base64_encode(self, data~) {
  ignore(self)
  base64_encode_impl(data)
}

///|
pub impl @interfaces.Crypto for JsCrypto with base64_decode(self, data~) {
  ignore(self)
  base64_decode_impl(data)
}

// =============================================================================
// Base64 Implementation
// =============================================================================

///|
let base64_chars : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
fn base64_encode_impl(data : Bytes) -> String {
  let sb = StringBuilder::new()
  let len = data.length()
  let mut i = 0
  while i < len {
    let b0 = data[i].to_int()
    let b1 = if i + 1 < len { data[i + 1].to_int() } else { 0 }
    let b2 = if i + 2 < len { data[i + 2].to_int() } else { 0 }
    // 3バイトを4つの6ビット値に変換
    let c0 = (b0.reinterpret_as_uint() >> 2).reinterpret_as_int() & 0x3F
    let c1 = (
        ((b0 & 0x03) << 4) |
        (b1.reinterpret_as_uint() >> 4).reinterpret_as_int()
      ) &
      0x3F
    let c2 = (
        ((b1 & 0x0F) << 2) |
        (b2.reinterpret_as_uint() >> 6).reinterpret_as_int()
      ) &
      0x3F
    let c3 = b2 & 0x3F
    sb.write_char(base64_char_at(c0))
    sb.write_char(base64_char_at(c1))
    if i + 1 < len {
      sb.write_char(base64_char_at(c2))
    } else {
      sb.write_char('=')
    }
    if i + 2 < len {
      sb.write_char(base64_char_at(c3))
    } else {
      sb.write_char('=')
    }
    i = i + 3
  }
  sb.to_string()
}

///|
fn base64_char_at(index : Int) -> Char {
  base64_chars[index].unsafe_to_char()
}

///|
fn base64_decode_impl(data : String) -> Bytes raise CryptoError {
  let len = data.length()
  if len == 0 {
    return Bytes::new(0)
  }
  if len % 4 != 0 {
    raise CryptoError::DecodeError("Invalid base64 length")
  }
  // パディングを除いた実際のバイト数を計算
  let eq_code = '='.to_int()
  let padding = if data[len - 1].to_int() == eq_code {
    if data[len - 2].to_int() == eq_code {
      2
    } else {
      1
    }
  } else {
    0
  }
  let output_len = len / 4 * 3 - padding
  let output : FixedArray[Byte] = FixedArray::make(output_len, b'\x00')
  let mut out_idx = 0
  let mut i = 0
  while i < len {
    let char0 = data[i].unsafe_to_char()
    let char1 = data[i + 1].unsafe_to_char()
    let char2 = data[i + 2].unsafe_to_char()
    let char3 = data[i + 3].unsafe_to_char()
    let c0 = base64_decode_char(char0)
    let c1 = base64_decode_char(char1)
    let c2 = if char2 == '=' { 0 } else { base64_decode_char(char2) }
    let c3 = if char3 == '=' { 0 } else { base64_decode_char(char3) }
    if c0 < 0 || c1 < 0 || c2 < 0 || c3 < 0 {
      raise CryptoError::DecodeError("Invalid base64 character")
    }
    // 4つの6ビット値を3バイトに変換
    if out_idx < output_len {
      output[out_idx] = ((c0 << 2) |
      (c1.reinterpret_as_uint() >> 4).reinterpret_as_int()).to_byte()
      out_idx = out_idx + 1
    }
    if out_idx < output_len {
      output[out_idx] = (((c1 & 0x0F) << 4) |
      (c2.reinterpret_as_uint() >> 2).reinterpret_as_int()).to_byte()
      out_idx = out_idx + 1
    }
    if out_idx < output_len {
      output[out_idx] = (((c2 & 0x03) << 6) | c3).to_byte()
      out_idx = out_idx + 1
    }
    i = i + 4
  }
  Bytes::from_array(output[:])
}

///|
fn base64_decode_char(c : Char) -> Int {
  let code = c.to_int()
  if code >= 65 && code <= 90 {
    // A-Z
    code - 65
  } else if code >= 97 && code <= 122 {
    // a-z
    code - 97 + 26
  } else if code >= 48 && code <= 57 {
    // 0-9
    code - 48 + 52
  } else if code == 43 {
    // +
    62
  } else if code == 47 {
    // /
    63
  } else {
    -1
  }
}

// =============================================================================
// SHA-256 Implementation
// =============================================================================

///|
/// SHA-256 初期ハッシュ値
let sha256_h0 : FixedArray[UInt] = [
  0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU, 0x510e527fU, 0x9b05688cU, 0x1f83d9abU,
  0x5be0cd19U,
]

///|
/// SHA-256 ラウンド定数
let sha256_k : FixedArray[UInt] = [
  0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U, 0x923f82a4U,
  0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U, 0x72be5d74U, 0x80deb1feU,
  0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU,
  0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU, 0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U,
  0xc6e00bf3U, 0xd5a79147U, 0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU,
  0x53380d13U, 0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
  0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U, 0x19a4c116U,
  0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU, 0x682e6ff3U,
  0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U, 0x90befffaU, 0xa4506cebU, 0xbef9a3f7U,
  0xc67178f2U,
]

///|
fn sha256_hash(data : Bytes) -> Bytes {
  // メッセージをパディング
  let padded = sha256_pad_message(data)
  // ハッシュ状態を初期化
  let h : FixedArray[UInt] = FixedArray::make(8, 0U)
  for i in 0..<8 {
    h[i] = sha256_h0[i]
  }
  // 各512ビットブロックを処理
  let num_blocks = padded.length() / 64
  for block_idx in 0..<num_blocks {
    sha256_process_block(padded, block_idx * 64, h)
  }
  // ハッシュ値をバイト配列に変換
  let result : FixedArray[Byte] = FixedArray::make(32, b'\x00')
  for i in 0..<8 {
    let word = h[i]
    result[i * 4] = (word >> 24).reinterpret_as_int().to_byte()
    result[i * 4 + 1] = ((word >> 16) & 0xFFU).reinterpret_as_int().to_byte()
    result[i * 4 + 2] = ((word >> 8) & 0xFFU).reinterpret_as_int().to_byte()
    result[i * 4 + 3] = (word & 0xFFU).reinterpret_as_int().to_byte()
  }
  Bytes::from_array(result[:])
}

///|
fn sha256_pad_message(data : Bytes) -> Bytes {
  let original_len = data.length()
  let bit_len = (original_len * 8).to_int64()
  // パディング後の長さを計算（64バイトの倍数）
  let mut padded_len = original_len + 1 + 8 // 元データ + 0x80 + 長さ(8バイト)
  while padded_len % 64 != 0 {
    padded_len = padded_len + 1
  }
  let padded : FixedArray[Byte] = FixedArray::make(padded_len, b'\x00')
  // 元データをコピー
  for i in 0..<original_len {
    padded[i] = data[i]
  }
  // 0x80を追加
  padded[original_len] = b'\x80'
  // 長さをビッグエンディアンで追加（最後の8バイト）
  let len_offset = padded_len - 8
  padded[len_offset] = (bit_len >> 56).to_byte()
  padded[len_offset + 1] = ((bit_len >> 48) & 0xFFL).to_byte()
  padded[len_offset + 2] = ((bit_len >> 40) & 0xFFL).to_byte()
  padded[len_offset + 3] = ((bit_len >> 32) & 0xFFL).to_byte()
  padded[len_offset + 4] = ((bit_len >> 24) & 0xFFL).to_byte()
  padded[len_offset + 5] = ((bit_len >> 16) & 0xFFL).to_byte()
  padded[len_offset + 6] = ((bit_len >> 8) & 0xFFL).to_byte()
  padded[len_offset + 7] = (bit_len & 0xFFL).to_byte()
  Bytes::from_array(padded[:])
}

///|
fn sha256_process_block(
  data : Bytes,
  offset : Int,
  h : FixedArray[UInt],
) -> Unit {
  // メッセージスケジュールを構築
  let w : FixedArray[UInt] = FixedArray::make(64, 0U)
  // 最初の16ワードはブロックから
  for i in 0..<16 {
    let idx = offset + i * 4
    w[i] = (data[idx].to_int().reinterpret_as_uint() << 24) |
      (data[idx + 1].to_int().reinterpret_as_uint() << 16) |
      (data[idx + 2].to_int().reinterpret_as_uint() << 8) |
      data[idx + 3].to_int().reinterpret_as_uint()
  }
  // 残りの48ワードを計算
  for i in 16..<64 {
    let s0 = sha256_rotr(w[i - 15], 7) ^
      sha256_rotr(w[i - 15], 18) ^
      (w[i - 15] >> 3)
    let s1 = sha256_rotr(w[i - 2], 17) ^
      sha256_rotr(w[i - 2], 19) ^
      (w[i - 2] >> 10)
    w[i] = w[i - 16] + s0 + w[i - 7] + s1
  }
  // ワーキング変数を初期化
  let mut a = h[0]
  let mut b = h[1]
  let mut c = h[2]
  let mut d = h[3]
  let mut e = h[4]
  let mut f = h[5]
  let mut g = h[6]
  let mut hh = h[7]
  // 64ラウンドの圧縮
  for i in 0..<64 {
    let s1 = sha256_rotr(e, 6) ^ sha256_rotr(e, 11) ^ sha256_rotr(e, 25)
    let ch = (e & f) ^ ((e ^ 0xFFFFFFFFU) & g)
    let temp1 = hh + s1 + ch + sha256_k[i] + w[i]
    let s0 = sha256_rotr(a, 2) ^ sha256_rotr(a, 13) ^ sha256_rotr(a, 22)
    let maj = (a & b) ^ (a & c) ^ (b & c)
    let temp2 = s0 + maj
    hh = g
    g = f
    f = e
    e = d + temp1
    d = c
    c = b
    b = a
    a = temp1 + temp2
  }
  // ハッシュ値を更新
  h[0] = h[0] + a
  h[1] = h[1] + b
  h[2] = h[2] + c
  h[3] = h[3] + d
  h[4] = h[4] + e
  h[5] = h[5] + f
  h[6] = h[6] + g
  h[7] = h[7] + hh
}

///|
fn sha256_rotr(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

// =============================================================================
// HMAC-SHA256 Implementation
// =============================================================================

///|
fn hmac_sha256_compute(key : Bytes, data : Bytes) -> Bytes {
  let block_size = 64
  // キーを正規化
  let normalized_key = if key.length() > block_size {
    sha256_hash(key)
  } else {
    key
  }
  // キーをブロックサイズにパディング
  let padded_key : FixedArray[Byte] = FixedArray::make(block_size, b'\x00')
  for i in 0..<normalized_key.length() {
    padded_key[i] = normalized_key[i]
  }
  // inner padとouter padを計算
  let ipad : FixedArray[Byte] = FixedArray::make(block_size, b'\x36')
  let opad : FixedArray[Byte] = FixedArray::make(block_size, b'\x5c')
  for i in 0..<block_size {
    ipad[i] = (padded_key[i].to_int() ^ 0x36).to_byte()
    opad[i] = (padded_key[i].to_int() ^ 0x5c).to_byte()
  }
  // inner hash: SHA256(ipad || data)
  let inner_data : FixedArray[Byte] = FixedArray::make(
    block_size + data.length(),
    b'\x00',
  )
  for i in 0..<block_size {
    inner_data[i] = ipad[i]
  }
  for i in 0..<data.length() {
    inner_data[block_size + i] = data[i]
  }
  let inner_hash = sha256_hash(Bytes::from_array(inner_data[:]))
  // outer hash: SHA256(opad || inner_hash)
  let outer_data : FixedArray[Byte] = FixedArray::make(block_size + 32, b'\x00')
  for i in 0..<block_size {
    outer_data[i] = opad[i]
  }
  for i in 0..<32 {
    outer_data[block_size + i] = inner_hash[i]
  }
  sha256_hash(Bytes::from_array(outer_data[:]))
}

// =============================================================================
// Hex encoding helper (for debugging)
// =============================================================================

///|
pub fn bytes_to_hex(data : Bytes) -> String {
  let sb = StringBuilder::new()
  for b in data {
    let n = b.to_int()
    sb.write_char(
      hex_char((n.reinterpret_as_uint() >> 4).reinterpret_as_int() & 0xF),
    )
    sb.write_char(hex_char(n & 0xF))
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
