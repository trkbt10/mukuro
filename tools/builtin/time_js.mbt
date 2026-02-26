///|
/// JS向け時刻取得関数

///|
extern "js" fn js_date_now_ms() -> Double =
  #|() => Date.now()

///|
/// 現在時刻を取得（ミリ秒）- JS実装
fn get_current_time_ms() -> Int64 {
  js_date_now_ms().to_int64()
}
