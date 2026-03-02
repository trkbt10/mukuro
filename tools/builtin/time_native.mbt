///|
/// Native向け時刻取得関数

///|
/// time() ラッパー - 直接バインドすると引数の扱いで問題が発生するため
extern "C" fn c_time_builtin() -> Int64 = "moonbit_builtin_time_now"

///|
/// 現在時刻を取得（ミリ秒）- Native実装
pub fn get_current_time_ms() -> Int64 {
  // time() は秒精度なので、ミリ秒に変換
  c_time_builtin() * 1000L
}
