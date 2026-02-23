///|
/// Native Timer 実装
/// 注: 真の非同期タイマーにはイベントループ（libuv等）が必要
/// この実装はシングルスレッド環境での簡易的なタイマー

///|
/// タイマーエントリ
struct TimerEntry {
  /// タイマーID
  id : String
  /// 発火時刻（Unix epoch ms）
  fire_at : Int64
  /// コールバック
  callback : () -> Unit
  /// 繰り返し間隔（0の場合はワンショット）
  interval_ms : Int64
  /// アクティブかどうか
  mut active : Bool
}

///|
/// Native タイマー実装
pub struct NativeTimer {
  /// 登録されたタイマー
  timers : Map[String, TimerEntry]
  /// 次のタイマーID
  mut next_id : Int
  /// 時計
  clock : NativeClock
}

///|
/// NativeTimerを新規作成
pub fn NativeTimer::new() -> NativeTimer {
  { timers: {}, next_id: 1, clock: NativeClock::new() }
}

///|
/// 新しいタイマーIDを生成
fn NativeTimer::generate_id(self : NativeTimer) -> String {
  let id = "native_timer_\{self.next_id}"
  self.next_id = self.next_id + 1
  id
}

///|
/// Timer トレイト実装
pub impl @interfaces.Timer for NativeTimer with now(self) {
  self.clock.now_ms()
}

///|
pub impl @interfaces.Timer for NativeTimer with set_timeout(
  self,
  delay_ms~,
  callback~,
) {
  let timer_id = self.generate_id()
  let fire_at = self.clock.now_ms() + delay_ms
  self.timers[timer_id] = {
    id: timer_id,
    fire_at,
    callback,
    interval_ms: 0L,
    active: true,
  }
  timer_id
}

///|
pub impl @interfaces.Timer for NativeTimer with set_interval(
  self,
  interval_ms~,
  callback~,
) {
  let timer_id = self.generate_id()
  let fire_at = self.clock.now_ms() + interval_ms
  self.timers[timer_id] = {
    id: timer_id,
    fire_at,
    callback,
    interval_ms,
    active: true,
  }
  timer_id
}

///|
pub impl @interfaces.Timer for NativeTimer with cancel(self, timer_id~) {
  match self.timers.get(timer_id) {
    Some(entry) => {
      entry.active = false
      self.timers.remove(timer_id)
    }
    None => ()
  }
}

///|
/// ポーリングベースのタイマー処理
/// イベントループから定期的に呼び出す
pub fn NativeTimer::tick(self : NativeTimer) -> Unit {
  let now = self.clock.now_ms()
  let to_remove : Array[String] = []
  let to_reschedule : Array[(String, TimerEntry)] = []
  for timer_id, entry in self.timers {
    if entry.active && entry.fire_at <= now {
      // コールバックを実行
      (entry.callback)()
      if entry.interval_ms > 0L {
        // インターバルタイマーは再スケジュール
        to_reschedule.push(
          (
            timer_id,
            {
              id: entry.id,
              fire_at: now + entry.interval_ms,
              callback: entry.callback,
              interval_ms: entry.interval_ms,
              active: true,
            },
          ),
        )
      } else {
        // ワンショットタイマーは削除
        to_remove.push(timer_id)
      }
    }
  }
  // 削除
  for id in to_remove {
    self.timers.remove(id)
  }
  // 再スケジュール
  for pair in to_reschedule {
    let (id, entry) = pair
    self.timers.set(id, entry)
  }
}

///|
/// 次のタイマー発火までの時間（ミリ秒）
pub fn NativeTimer::next_fire_in(self : NativeTimer) -> Int64? {
  let now = self.clock.now_ms()
  let mut min_delay : Int64? = None
  for _, entry in self.timers {
    if entry.active {
      let delay = entry.fire_at - now
      match min_delay {
        Some(current) => if delay < current { min_delay = Some(delay) }
        None => min_delay = Some(delay)
      }
    }
  }
  min_delay
}

///|
/// アクティブなタイマー数
pub fn NativeTimer::active_count(self : NativeTimer) -> Int {
  let mut count = 0
  for _, entry in self.timers {
    if entry.active {
      count = count + 1
    }
  }
  count
}

///|
/// 全タイマーをキャンセル
pub fn NativeTimer::cancel_all(self : NativeTimer) -> Unit {
  self.timers.clear()
}

///|
/// 簡易イベントループ
/// 注: これはブロッキングループであり、実際のアプリケーションでは
/// libuv や他のイベントループライブラリを使用すべき
pub fn NativeTimer::run_loop(self : NativeTimer, max_iterations : Int) -> Unit {
  let mut iteration = 0
  while iteration < max_iterations && self.active_count() > 0 {
    self.tick()
    // スリープ（簡易実装）
    // 実際にはusleepやnanosleepを使用
    iteration = iteration + 1
  }
}
