///|
/// JavaScript環境向けタイマー実装

///|
/// JSタイマーID型
#external
type JsTimerId

///|
/// setInterval
extern "js" fn js_set_interval(callback : () -> Unit, ms : Int) -> JsTimerId =
  #|(callback, ms) => setInterval(callback, ms)

///|
/// clearInterval
extern "js" fn js_clear_interval(id : JsTimerId) -> Unit =
  #|(id) => clearInterval(id)

///|
/// setTimeout
extern "js" fn js_set_timeout(callback : () -> Unit, ms : Int) -> JsTimerId =
  #|(callback, ms) => setTimeout(callback, ms)

///|
/// clearTimeout
extern "js" fn js_clear_timeout(id : JsTimerId) -> Unit =
  #|(id) => clearTimeout(id)

///|
/// タイマー種別
pub(all) enum TimerType {
  /// 一度だけ実行
  OneShot
  /// 繰り返し実行
  Interval
}

///|
/// タイマーハンドル
pub struct TimerHandle {
  /// タイマーID
  id : JsTimerId
  /// タイマー種別
  timer_type : TimerType
  /// アクティブかどうか
  mut active : Bool
}

///|
/// タイマーをキャンセル
pub fn TimerHandle::cancel(self : TimerHandle) -> Unit {
  if self.active {
    match self.timer_type {
      TimerType::OneShot => js_clear_timeout(self.id)
      TimerType::Interval => js_clear_interval(self.id)
    }
    self.active = false
  }
}

///|
/// タイマーマネージャ
pub struct TimerManager {
  /// アクティブなタイマー
  timers : Map[String, TimerHandle]
  /// 次のタイマーID
  mut next_id : Int
}

///|
/// TimerManagerを新規作成
pub fn TimerManager::new() -> TimerManager {
  { timers: {}, next_id: 1 }
}

///|
/// 新しいタイマーIDを生成
fn TimerManager::generate_id(self : TimerManager) -> String {
  let id = "timer_\{self.next_id}"
  self.next_id = self.next_id + 1
  id
}

///|
/// 一度だけ実行するタイマーを設定
pub fn TimerManager::set_timeout(
  self : TimerManager,
  delay_ms : Int,
  callback : () -> Unit,
) -> String {
  let timer_id = self.generate_id()
  let js_id = js_set_timeout(callback, delay_ms)
  self.timers[timer_id] = {
    id: js_id,
    timer_type: TimerType::OneShot,
    active: true,
  }
  timer_id
}

///|
/// 繰り返し実行するタイマーを設定
pub fn TimerManager::set_interval(
  self : TimerManager,
  interval_ms : Int,
  callback : () -> Unit,
) -> String {
  let timer_id = self.generate_id()
  let js_id = js_set_interval(callback, interval_ms)
  self.timers[timer_id] = {
    id: js_id,
    timer_type: TimerType::Interval,
    active: true,
  }
  timer_id
}

///|
/// タイマーをキャンセル
pub fn TimerManager::cancel_timer(
  self : TimerManager,
  timer_id : String,
) -> Bool {
  match self.timers.get(timer_id) {
    Some(handle) => {
      handle.cancel()
      self.timers.remove(timer_id)
      true
    }
    None => false
  }
}

///|
/// 全タイマーをキャンセル
pub fn TimerManager::cancel_all(self : TimerManager) -> Unit {
  for _, handle in self.timers {
    handle.cancel()
  }
  self.timers.clear()
}

///|
/// スケジューラタイマー
/// TaskSchedulerと連携してcronタスクを実行
pub struct SchedulerTimer {
  /// タイマーマネージャ
  timer_manager : TimerManager
  /// タスクスケジューラ
  scheduler : @core_scheduler.TaskScheduler
  /// ハートビートマネージャ
  heartbeat : @core_scheduler.HeartbeatManager
  /// チェック間隔（ミリ秒）
  check_interval_ms : Int
  /// メインタイマーID
  mut main_timer_id : String?
  /// ハートビートタイマーID
  mut heartbeat_timer_id : String?
}

///|
/// SchedulerTimerを新規作成
pub fn SchedulerTimer::new(
  scheduler~ : @core_scheduler.TaskScheduler,
  heartbeat~ : @core_scheduler.HeartbeatManager,
  check_interval_ms~ : Int,
) -> SchedulerTimer {
  {
    timer_manager: TimerManager::new(),
    scheduler,
    heartbeat,
    check_interval_ms,
    main_timer_id: None,
    heartbeat_timer_id: None,
  }
}

///|
/// スケジューラを開始
pub fn SchedulerTimer::start(
  self : SchedulerTimer,
  on_task : (@core_scheduler.ScheduledTask) -> Unit,
) -> Unit {
  // メインスケジューラタイマー
  let main_id = self.timer_manager.set_interval(self.check_interval_ms, fn() {
    let current_time = @js.js_date_now() / 1000L
    let due_tasks = self.scheduler.due_tasks(current_time)
    for task in due_tasks {
      on_task(task)
    }
  })
  self.main_timer_id = Some(main_id)
  // ハートビートタイマー
  let hb_id = self.timer_manager.set_interval(
    self.heartbeat.config.interval_ms.to_int(),
    fn() {
      let current_time = @js.js_date_now()
      self.heartbeat.update_all_statuses(current_time)
    },
  )
  self.heartbeat_timer_id = Some(hb_id)
}

///|
/// スケジューラを停止
pub fn SchedulerTimer::stop(self : SchedulerTimer) -> Unit {
  match self.main_timer_id {
    Some(id) => {
      let _ = self.timer_manager.cancel_timer(id)
      self.main_timer_id = None
    }
    None => ()
  }
  match self.heartbeat_timer_id {
    Some(id) => {
      let _ = self.timer_manager.cancel_timer(id)
      self.heartbeat_timer_id = None
    }
    None => ()
  }
}

///|
/// 実行中かどうか
pub fn SchedulerTimer::is_running(self : SchedulerTimer) -> Bool {
  match self.main_timer_id {
    Some(_) => true
    None => false
  }
}
