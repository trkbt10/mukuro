///|
/// Native向け時刻取得関数

///|
extern "C" fn c_time_builtin() -> Int64 = "moonbit_builtin_time_now"

///|
/// 現在時刻を取得（ミリ秒）- Native実装
pub fn get_current_time_ms() -> Int64 {
  c_time_builtin() * 1000L
}
