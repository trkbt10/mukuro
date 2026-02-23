///|
/// スケジュール種別
pub(all) enum Schedule {
  /// cron式（"*/5 * * * *" など）
  Cron(String)
  /// 固定間隔（ミリ秒）
  Interval(Int64)
  /// 一回限り（Unix epoch ms）
  Once(Int64)
}

///|
/// スケジュールされたタスク
pub(all) struct ScheduledTask {
  /// タスクID
  id : String
  /// スケジュール
  schedule : Schedule
  /// タスク実行時に生成するエンベロープ
  envelope_template : @types.InboundEnvelope
  /// 有効/無効
  enabled : Bool
}

///|
/// スケジューラ トレイト
/// cron/heartbeatなどの時間駆動タスクを管理する
pub(open) trait Scheduler {
  /// タスクを登録
  register(Self, ScheduledTask) -> Unit raise
  /// タスクを削除
  unregister(Self, task_id~ : String) -> Unit raise
  /// タスクを取得
  get_task(Self, task_id~ : String) -> ScheduledTask? raise
  /// 全タスクのリスト
  list_tasks(Self) -> Array[ScheduledTask] raise
  /// 次の実行時刻を取得
  next_tick(Self) -> Int64?
  /// 実行すべきタスクを取得（現在時刻ベース）
  due_tasks(Self, now~ : Int64) -> Array[ScheduledTask]
}

///|
/// タイマー トレイト
/// プラットフォーム固有のタイマー機能を抽象化
pub(open) trait Timer {
  /// 現在時刻を取得（Unix epoch ms）
  now(Self) -> Int64
  /// 指定時間後にコールバック（ミリ秒）
  set_timeout(Self, delay_ms~ : Int64, callback~ : () -> Unit) -> String
  /// 定期的にコールバック（ミリ秒）
  set_interval(Self, interval_ms~ : Int64, callback~ : () -> Unit) -> String
  /// タイマーをキャンセル
  cancel(Self, timer_id~ : String) -> Unit
}
