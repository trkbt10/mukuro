///|
/// JS向け時刻取得関数

///|
/// 現在時刻を取得（ミリ秒）- JS実装
fn get_current_time_ms() -> Int64 {
  @js.js_date_now()
}
