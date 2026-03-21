///|
/// CLI Cron Commands
/// Cron job management

///|
/// Cronコマンドを実行
pub fn execute_cron_command(cmd : @cli.CronCommand) -> @cli.CliResult {
  match cmd {
    @cli.CronCommand::List => execute_cron_list()
    @cli.CronCommand::Unknown(name) =>
      @cli.CliResult::Error("Unknown cron command: \{name}")
  }
}

///|
/// Cronジョブ一覧を表示
fn execute_cron_list() -> @cli.CliResult {
  // TaskSchedulerインスタンスを作成
  let scheduler = @scheduler.TaskScheduler::new()
  let tasks = scheduler.get_all_tasks()
  if tasks.is_empty() {
    return @cli.CliResult::Ok("No cron jobs scheduled")
  }
  let mut output = "Cron Jobs:\n"
  for task in tasks {
    output = output + "  - \{task.name}: (enabled: \{task.enabled})\n"
  }
  @cli.CliResult::Ok(output)
}
