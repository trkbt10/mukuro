/// BytesView から Bytes へのコピー
/// Bytes::from_iter(buffer[:len].iter()) の置換
pub fn copy_slice(view : BytesView) -> Bytes {
  Bytes::from_iter(view.iter())
}
