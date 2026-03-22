///|
/// Heartbeat Runner — HEARTBEAT.md パース + 定期実行トリガー

///|
/// HEARTBEAT.md からチェックリストタスクを抽出
/// フォーマット: `- [ ] Task description` (未完了) / `- [x] Task description` (完了)
pub fn parse_heartbeat_tasks(content : String) -> Array[(String, Bool)] {
  let tasks : Array[(String, Bool)] = []
  let lines = content.split("\n")
  for line_view in lines {
    let line = line_view.to_string()
    let trimmed = line.trim(chars=" \t").to_string()
    if trimmed.has_prefix("- [ ] ") {
      let task_name = trimmed[6:].to_string()
      tasks.push((task_name, false))
    } else if trimmed.has_prefix("- [x] ") || trimmed.has_prefix("- [X] ") {
      let task_name = trimmed[6:].to_string()
      tasks.push((task_name, true))
    }
  }
  tasks
}

///|
/// 未完了のタスクのみ抽出
pub fn get_pending_heartbeat_tasks(content : String) -> Array[String] {
  let all_tasks = parse_heartbeat_tasks(content)
  let pending : Array[String] = []
  for task in all_tasks {
    if not(task.1) {
      pending.push(task.0)
    }
  }
  pending
}

///|
/// Heartbeat 用の Cron ジョブを TaskScheduler に登録
/// interval_minutes ごとに実行
pub fn register_heartbeat_cron(
  scheduler : TaskScheduler,
  interval_minutes : Int,
) -> Unit {
  // interval_minutes を cron 式に変換: */N * * * *
  let cron_expr = "*/\{interval_minutes} * * * *"
  let task = ScheduledTask::new(
    id="__heartbeat__",
    name="Heartbeat",
    cron_expr~,
    payload={ "type": "heartbeat" },
  ) catch {
    _ => return // cron パースエラー
  }
  scheduler.register(task)
}

///|
/// Heartbeat タスクのサマリーを生成（エージェントへの入力用）
pub fn build_heartbeat_prompt(pending_tasks : Array[String]) -> String {
  if pending_tasks.is_empty() {
    return "No pending heartbeat tasks."
  }
  let buf = StringBuilder::new()
  buf.write_string("Heartbeat check — review these pending tasks:\n\n")
  for task in pending_tasks {
    buf.write_string("- [ ] \{task}\n")
  }
  buf.write_string(
    "\nFor each task, determine if action is needed and take appropriate steps.",
  )
  buf.to_string()
}
