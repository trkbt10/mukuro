/// FFI読み取りバッファからUTF-8文字列へのデコード
/// 中間 Bytes コピー不要で直接 BytesView を受け取る
pub fn decode_utf8(view : BytesView) -> String? {
  let s = @utf8.decode(view) catch { _ => return None }
  Some(s)
}

/// decode_utf8 のデフォルト値付き便利版
pub fn decode_utf8_or(view : BytesView, default~ : String) -> String {
  match decode_utf8(view) {
    Some(s) => s
    None => default
  }
}

/// 文字列をUTF-8バイト列にエンコード（@utf8.encode の薄いラッパー）
pub fn encode_utf8(s : String) -> Bytes {
  @utf8.encode(s)
}

/// null終端UTF-8バイト列の生成（C FFI用）
pub fn to_utf8_cstring(s : String) -> Bytes {
  let utf8 = @utf8.encode(s)
  let arr : Array[Byte] = Array::new(capacity=utf8.length() + 1)
  for b in utf8 {
    arr.push(b)
  }
  arr.push(b'\x00')
  Bytes::from_iter(arr.iter())
}
