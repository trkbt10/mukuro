///|
/// Cron式パーサー・評価
/// 標準的なcron式（分 時 日 月 曜日）をサポート

///|
/// Cron式パースエラー
pub(all) suberror CronParseError {
  InvalidFormat(String)
  InvalidField(String, Int)
  InvalidRange(Int, Int, Int)
  InvalidValue(String, Int)
}

///|
/// Cronフィールド（各時間単位の許可値）
pub struct CronField {
  /// 許可された値のリスト
  values : Array[Int]
  /// 最小値
  min : Int
  /// 最大値
  max : Int
}

///|
/// CronFieldを新規作成
pub fn CronField::new(min~ : Int, max~ : Int) -> CronField {
  { values: [], min, max }
}

///|
/// 値が含まれるか確認
pub fn CronField::contains(self : CronField, value : Int) -> Bool {
  for v in self.values {
    if v == value {
      return true
    }
  }
  false
}

///|
/// ワイルドカード（全値を許可）
pub fn CronField::wildcard(min~ : Int, max~ : Int) -> CronField {
  let values : Array[Int] = []
  for i in min..<=max {
    values.push(i)
  }
  { values, min, max }
}

///|
/// Cron式
pub struct CronExpression {
  /// 分 (0-59)
  minute : CronField
  /// 時 (0-23)
  hour : CronField
  /// 日 (1-31)
  day_of_month : CronField
  /// 月 (1-12)
  month : CronField
  /// 曜日 (0-6, 0=日曜)
  day_of_week : CronField
}

///|
/// Cron式をパース
pub fn parse_cron(expr : String) -> CronExpression raise CronParseError {
  let parts = expr.split(" ").collect()
  if parts.length() != 5 {
    raise CronParseError::InvalidFormat(
      "Expected 5 fields, got \{parts.length()}",
    )
  }
  let minute = parse_field(parts[0].to_string(), 0, 59, 0)
  let hour = parse_field(parts[1].to_string(), 0, 23, 1)
  let day_of_month = parse_field(parts[2].to_string(), 1, 31, 2)
  let month = parse_field(parts[3].to_string(), 1, 12, 3)
  let day_of_week = parse_field(parts[4].to_string(), 0, 6, 4)
  { minute, hour, day_of_month, month, day_of_week }
}

///|
/// フィールドをパース
fn parse_field(
  field : String,
  min : Int,
  max : Int,
  field_index : Int,
) -> CronField raise CronParseError {
  // ワイルドカード
  if field == "*" {
    return CronField::wildcard(min~, max~)
  }
  // カンマ区切りの複数値
  if field.contains(",") {
    let result = CronField::new(min~, max~)
    for part in field.split(",") {
      let sub_field = parse_field(part.to_string(), min, max, field_index)
      for v in sub_field.values {
        if not(result.contains(v)) {
          result.values.push(v)
        }
      }
    }
    return result
  }
  // 範囲 (n-m)
  if field.contains("-") {
    let parts = field.split("-").collect()
    if parts.length() != 2 {
      raise CronParseError::InvalidField(field, field_index)
    }
    let start = parse_int_or_error(parts[0].to_string(), field_index)
    let end = parse_int_or_error(parts[1].to_string(), field_index)
    if start > end || start < min || end > max {
      raise CronParseError::InvalidRange(start, end, field_index)
    }
    let result = CronField::new(min~, max~)
    for i in start..<=end {
      result.values.push(i)
    }
    return result
  }
  // ステップ値 (*/n or n/m)
  if field.contains("/") {
    let parts = field.split("/").collect()
    if parts.length() != 2 {
      raise CronParseError::InvalidField(field, field_index)
    }
    let step = parse_int_or_error(parts[1].to_string(), field_index)
    let base = parts[0].to_string()
    let start = if base == "*" {
      min
    } else {
      parse_int_or_error(base, field_index)
    }
    let result = CronField::new(min~, max~)
    let mut current = start
    while current <= max {
      result.values.push(current)
      current = current + step
    }
    return result
  }
  // 単一値
  let value = parse_int_or_error(field, field_index)
  if value < min || value > max {
    raise CronParseError::InvalidValue(field, field_index)
  }
  let result = CronField::new(min~, max~)
  result.values.push(value)
  result
}

///|
/// 文字列を整数にパース
fn parse_int_or_error(
  s : String,
  field_index : Int,
) -> Int raise CronParseError {
  let result : Json = @json.parse(s) catch {
    _ => raise CronParseError::InvalidValue(s, field_index)
  }
  match result {
    Number(n, ..) => n.to_int()
    _ => raise CronParseError::InvalidValue(s, field_index)
  }
}

///|
/// 時刻がCron式にマッチするか確認
pub fn CronExpression::matches(
  self : CronExpression,
  minute : Int,
  hour : Int,
  day_of_month : Int,
  month : Int,
  day_of_week : Int,
) -> Bool {
  self.minute.contains(minute) &&
  self.hour.contains(hour) &&
  self.day_of_month.contains(day_of_month) &&
  self.month.contains(month) &&
  self.day_of_week.contains(day_of_week)
}

///|
/// Unix時刻がCron式にマッチするか確認（簡易版）
pub fn CronExpression::matches_timestamp(
  self : CronExpression,
  timestamp_seconds : Int64,
) -> Bool {
  // Unix時刻から日時を取得（簡易実装）
  let seconds_per_minute = 60L
  let seconds_per_hour = 3600L
  let seconds_per_day = 86400L
  // UTC時刻を計算
  let time_of_day = timestamp_seconds % seconds_per_day
  let minute = (time_of_day % seconds_per_hour / seconds_per_minute).to_int()
  let hour = (time_of_day / seconds_per_hour).to_int()
  // 日付の計算は複雑なので、この簡易版では分と時のみチェック
  // 完全な実装には追加のロジックが必要
  self.minute.contains(minute) && self.hour.contains(hour)
}

///|
/// スケジュールタスク
pub(all) struct ScheduledTask {
  /// タスクID
  id : String
  /// タスク名
  name : String
  /// Cron式
  cron : CronExpression
  /// 次回実行時刻（Unix秒）
  mut next_run : Int64
  /// 有効かどうか
  mut enabled : Bool
  /// 実行ペイロード
  payload : Json
}

///|
/// ScheduledTaskを新規作成
pub fn ScheduledTask::new(
  id~ : String,
  name~ : String,
  cron_expr~ : String,
  payload~ : Json,
) -> ScheduledTask raise CronParseError {
  let cron = parse_cron(cron_expr)
  { id, name, cron, next_run: 0L, enabled: true, payload }
}

///|
/// タスクスケジューラ
pub struct TaskScheduler {
  /// 登録されたタスク
  tasks : Map[String, ScheduledTask]
}

///|
/// TaskSchedulerを新規作成
pub fn TaskScheduler::new() -> TaskScheduler {
  { tasks: {} }
}

///|
/// タスクを登録
pub fn TaskScheduler::register(
  self : TaskScheduler,
  task : ScheduledTask,
) -> Unit {
  self.tasks[task.id] = task
}

///|
/// タスクを解除
pub fn TaskScheduler::unregister(
  self : TaskScheduler,
  task_id : String,
) -> Bool {
  match self.tasks.get(task_id) {
    Some(_) => {
      self.tasks.remove(task_id)
      true
    }
    None => false
  }
}

///|
/// 実行すべきタスクを取得
pub fn TaskScheduler::due_tasks(
  self : TaskScheduler,
  current_time : Int64,
) -> Array[ScheduledTask] {
  let result : Array[ScheduledTask] = []
  for _, task in self.tasks {
    if task.enabled && task.cron.matches_timestamp(current_time) {
      result.push(task)
    }
  }
  result
}

///|
/// 全タスクを取得
pub fn TaskScheduler::get_all_tasks(
  self : TaskScheduler,
) -> Array[ScheduledTask] {
  let result : Array[ScheduledTask] = []
  for _, task in self.tasks {
    result.push(task)
  }
  result
}
