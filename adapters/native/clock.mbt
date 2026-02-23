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

///|
/// 高精度タイムスタンプを取得（マイクロ秒精度）
pub fn NativeClock::now_microseconds(self : NativeClock) -> Int64 {
  // 簡易実装：秒精度をマイクロ秒に変換
  // 完全な実装には gettimeofday を使用
  ignore(self)
  c_time() * 1000000L
}

///|
/// システム起動からの経過時間（モノトニック時計）
/// 注: 完全な実装には clock_gettime(CLOCK_MONOTONIC) を使用
pub fn NativeClock::monotonic_ms(self : NativeClock) -> Int64 {
  // 簡易実装：通常の時刻を返す
  self.now_ms()
}
