///|
/// CLI Cron Commands
/// Cron job management

///|
/// Cronコマンドを実行
pub fn execute_cron_command(cmd : CronCommand) -> CliResult {
  match cmd {
    CronCommand::List => execute_cron_list()
    CronCommand::Unknown(name) =>
      CliResult::Error("Unknown cron command: \{name}")
  }
}

///|
/// Cronジョブ一覧を表示
fn execute_cron_list() -> CliResult {
  // TaskSchedulerインスタンスを作成
  let scheduler = @scheduler.TaskScheduler::new()
  let tasks = scheduler.get_all_tasks()
  if tasks.is_empty() {
    return CliResult::Ok("No cron jobs scheduled")
  }
  let mut output = "Cron Jobs:\n"
  for task in tasks {
    output = output + "  - \{task.name}: (enabled: \{task.enabled})\n"
  }
  CliResult::Ok(output)
}
