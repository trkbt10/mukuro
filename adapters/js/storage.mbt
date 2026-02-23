///|
/// localStorage取得
extern "js" fn js_local_storage_get(key : String) -> JsValue =
  #|(key) => {
  #|  const val = localStorage.getItem(key);
  #|  return val === null ? undefined : val;
  #|}

///|
/// localStorage設定
extern "js" fn js_local_storage_set(key : String, value : String) -> Unit =
  #|(key, value) => localStorage.setItem(key, value)

///|
/// localStorage削除
extern "js" fn js_local_storage_remove(key : String) -> Unit =
  #|(key) => localStorage.removeItem(key)

///|
/// localStorageクリア
extern "js" fn _js_local_storage_clear() -> Unit =
  #|() => localStorage.clear()

///|
/// localStorageキー取得
extern "js" fn js_local_storage_key(index : Int) -> JsValue =
  #|(i) => localStorage.key(i) || undefined

///|
/// localStorage長さ取得
extern "js" fn js_local_storage_length() -> Int =
  #|() => localStorage.length

///|
/// localStorageが利用可能かどうか
extern "js" fn _js_local_storage_available() -> Bool =
  #|() => {
  #|  try {
  #|    const test = '__storage_test__';
  #|    localStorage.setItem(test, test);
  #|    localStorage.removeItem(test);
  #|    return true;
  #|  } catch (e) {
  #|    return false;
  #|  }
  #|}

///|
/// localStorage ベースのKVStore実装
pub struct LocalStorageKVStore {
  /// キープレフィックス
  prefix : String
}

///|
/// LocalStorageKVStoreを新規作成
pub fn LocalStorageKVStore::new(prefix~ : String) -> LocalStorageKVStore {
  { prefix, }
}

///|
/// デフォルト設定で作成
pub fn LocalStorageKVStore::default() -> LocalStorageKVStore {
  { prefix: "mukuro:" }
}

///|
/// フルキーを生成
fn LocalStorageKVStore::full_key(
  self : LocalStorageKVStore,
  key : String,
) -> String {
  "\{self.prefix}\{key}"
}

///|
/// KVStore実装
pub impl @interfaces.KVStore for LocalStorageKVStore with get(self, key~) {
  let full_key = self.full_key(key)
  let value = js_local_storage_get(full_key)
  if js_is_undefined(value) {
    None
  } else {
    Some(js_value_to_string(value))
  }
}

///|
pub impl @interfaces.KVStore for LocalStorageKVStore with set(
  self,
  key~,
  value~,
) {
  let full_key = self.full_key(key)
  js_local_storage_set(full_key, value)
}

///|
pub impl @interfaces.KVStore for LocalStorageKVStore with remove(self, key~) {
  let full_key = self.full_key(key)
  js_local_storage_remove(full_key)
}

///|
pub impl @interfaces.KVStore for LocalStorageKVStore with has(self, key~) {
  let full_key = self.full_key(key)
  let value = js_local_storage_get(full_key)
  not(js_is_undefined(value))
}

///|
pub impl @interfaces.KVStore for LocalStorageKVStore with keys(self) {
  let result : Array[String] = []
  let len = js_local_storage_length()
  for i in 0..<len {
    let key_value = js_local_storage_key(i)
    if not(js_is_undefined(key_value)) {
      let key = js_value_to_string(key_value)
      if key.has_prefix(self.prefix) {
        // プレフィックスを除去
        let actual_key = key
          .iter()
          .drop(self.prefix.length())
          .fold(init=StringBuilder::new(), fn(sb, c) {
            sb.write_char(c)
            sb
          })
          .to_string()
        result.push(actual_key)
      }
    }
  }
  result
}

///|
pub impl @interfaces.KVStore for LocalStorageKVStore with clear(self) {
  // プレフィックス付きのキーのみ削除
  let keys_to_remove = @interfaces.KVStore::keys(self)
  for key in keys_to_remove {
    @interfaces.KVStore::remove(self, key~)
  }
}

///|
/// インメモリKVStore（テスト用・フォールバック用）
pub struct InMemoryKVStore {
  data : Map[String, String]
}

///|
/// InMemoryKVStoreを新規作成
pub fn InMemoryKVStore::new() -> InMemoryKVStore {
  { data: {} }
}

///|
/// KVStore実装
pub impl @interfaces.KVStore for InMemoryKVStore with get(self, key~) {
  self.data.get(key)
}

///|
pub impl @interfaces.KVStore for InMemoryKVStore with set(self, key~, value~) {
  self.data[key] = value
}

///|
pub impl @interfaces.KVStore for InMemoryKVStore with remove(self, key~) {
  self.data.remove(key)
}

///|
pub impl @interfaces.KVStore for InMemoryKVStore with has(self, key~) {
  self.data.contains(key)
}

///|
pub impl @interfaces.KVStore for InMemoryKVStore with keys(self) {
  self.data.keys().collect()
}

///|
pub impl @interfaces.KVStore for InMemoryKVStore with clear(self) {
  self.data.clear()
}
