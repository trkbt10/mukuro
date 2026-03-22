///|
/// Memory ツール - Native 永続化実装
/// MemoryStore の内容を MEMORY.md に書き出す

///|
/// MemoryStore を MEMORY.md に永続化
fn persist_memory(store : MemoryStore) -> Unit {
  match store.persist_path {
    Some(path) => {
      let content = store.to_markdown()
      // fs_write を再利用 (filesystem_native.mbt で定義)
      let _ = fs_write(path, content)
    }
    None => () // persist_path 未設定 → 永続化なし
  }
}
