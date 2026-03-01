/// BytesView から Bytes へのコピー
/// NOTE: Bytes::from_iter は FFI で破損するため使用禁止 (CLAUDE.md 参照)
pub fn copy_slice(view : BytesView) -> Bytes {
  let len = view.length()
  Bytes::makei(len, fn(i) { view[i] })
}
