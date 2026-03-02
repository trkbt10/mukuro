///|
/// Native Clock 実装
/// POSIX time 関数を使用

///|
/// Native時計実装
pub struct NativeClock {
  /// プレースホルダ
  _placeholder : Unit
}

///|
/// NativeClockを新規作成
pub fn NativeClock::new() -> NativeClock {
  { _placeholder: () }
}

///|
/// Clock トレイト実装
pub impl @interfaces.Clock for NativeClock with now_ms(self) {
  // time() は秒精度なので、ミリ秒に変換
  // 注: 実際には gettimeofday を使うべき
  ignore(self)
  c_time() * 1000L
}

///|
pub impl @interfaces.Clock for NativeClock with now_seconds(self) {
  ignore(self)
  c_time()
}
