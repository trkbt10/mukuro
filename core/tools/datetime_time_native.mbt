///|
/// Native向け時刻取得関数
/// @native.c_time() を使用（adapters/native/ffi_time.mbt で定義）

///|
/// 現在時刻を取得（ミリ秒）- Native実装
pub fn get_current_time_ms() -> Int64 {
  @native.c_time() * 1000L
}
