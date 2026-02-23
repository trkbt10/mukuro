///|
/// Native向け時刻取得関数

///|
extern "C" fn c_time_builtin() -> Int64 = "time"

///|
/// 現在時刻を取得（ミリ秒）- Native実装
fn get_current_time_ms() -> Int64 {
  // time() は秒精度なので、ミリ秒に変換
  c_time_builtin() * 1000L
}
