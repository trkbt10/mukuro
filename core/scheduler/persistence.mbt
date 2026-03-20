///|
/// Cron ジョブ永続化 — TaskScheduler の JSON シリアライズ/デシリアライズ

///|
/// ScheduledTask を JSON にシリアライズ
pub fn task_to_json(task : ScheduledTask) -> Json {
  // cron 式を再構築するため、各フィールドの values を文字列化
  let cron_str = cron_expression_to_string(task.cron)
  {
    "id": task.id,
    "name": task.name,
    "cron": cron_str,
    "next_run": task.next_run.to_double(),
    "enabled": task.enabled,
    "payload": task.payload,
  }
}

///|
/// JSON から ScheduledTask をデシリアライズ
pub fn task_from_json(json : Json) -> ScheduledTask? {
  match json {
    { "id": String(id), "name": String(name), "cron": String(cron_str), .. } => {
      let cron = parse_cron(cron_str) catch { _ => return None }
      let next_run = match json {
        { "next_run": Number(n, ..), .. } => n.to_int64()
        _ => 0L
      }
      let enabled = match json {
        { "enabled": True, .. } => true
        { "enabled": False, .. } => false
        _ => true
      }
      let payload = match json {
        { "payload": p, .. } => p
        _ => Json::null()
      }
      Some({ id, name, cron, next_run, enabled, payload })
    }
    _ => None
  }
}

///|
/// TaskScheduler を JSON 配列にシリアライズ
pub fn scheduler_to_json(scheduler : TaskScheduler) -> Json {
  let tasks_json : Array[Json] = scheduler
    .get_all_tasks()
    .map(fn(t) { task_to_json(t) })
  Json::array(tasks_json)
}

///|
/// JSON 配列から TaskScheduler をデシリアライズ
pub fn scheduler_from_json(json : Json) -> TaskScheduler {
  let scheduler = TaskScheduler::new()
  match json {
    Array(tasks) =>
      for task_json in tasks {
        match task_from_json(task_json) {
          Some(task) => scheduler.register(task)
          None => ()
        }
      }
    _ => ()
  }
  scheduler
}

///|
/// CronExpression を文字列に変換
fn cron_expression_to_string(cron : CronExpression) -> String {
  let parts = [
    cron_field_to_string(cron.minute),
    cron_field_to_string(cron.hour),
    cron_field_to_string(cron.day_of_month),
    cron_field_to_string(cron.month),
    cron_field_to_string(cron.day_of_week),
  ]
  parts.join(" ")
}

///|
/// CronField を文字列に変換
fn cron_field_to_string(field : CronField) -> String {
  // 全値が含まれていれば * を返す
  let all_values = field.max - field.min + 1
  if field.values.length() >= all_values {
    return "*"
  }
  if field.values.is_empty() {
    return "*"
  }
  let strs : Array[String] = field.values.map(fn(v) { v.to_string() })
  strs.join(",")
}
