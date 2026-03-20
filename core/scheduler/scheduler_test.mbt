///|
/// Tests for cron parsing and task scheduling
test "CronField::wildcard matches all in range" {
  let field = @scheduler.CronField::wildcard(min=0, max=59)
  inspect(field.contains(0), content="true")
  inspect(field.contains(30), content="true")
  inspect(field.contains(59), content="true")
  // Outside range - values are explicitly added, so 60 won't be in the list
  inspect(field.contains(60), content="false")
}

///|
test "parse_cron with wildcard expression" {
  // Every minute: * * * * *
  let expr = @scheduler.parse_cron("* * * * *")
  inspect(expr.matches(0, 0, 1, 1, 0), content="true")
  inspect(expr.matches(30, 12, 15, 6, 3), content="true")
  inspect(expr.matches(59, 23, 31, 12, 6), content="true")
}

///|
test "parse_cron with specific values" {
  // At 10:30: 30 10 * * *
  let expr = @scheduler.parse_cron("30 10 * * *")
  inspect(expr.matches(30, 10, 1, 1, 0), content="true")
  inspect(expr.matches(30, 10, 15, 6, 3), content="true")
  // Wrong minute
  inspect(expr.matches(0, 10, 1, 1, 0), content="false")
  // Wrong hour
  inspect(expr.matches(30, 11, 1, 1, 0), content="false")
}

///|
test "parse_cron with range" {
  // Every minute from 0-5: 0-5 * * * *
  let expr = @scheduler.parse_cron("0-5 * * * *")
  inspect(expr.matches(0, 12, 1, 1, 0), content="true")
  inspect(expr.matches(3, 12, 1, 1, 0), content="true")
  inspect(expr.matches(5, 12, 1, 1, 0), content="true")
  inspect(expr.matches(6, 12, 1, 1, 0), content="false")
}

///|
test "parse_cron with step" {
  // Every 15 minutes: */15 * * * *
  let expr = @scheduler.parse_cron("*/15 * * * *")
  inspect(expr.matches(0, 12, 1, 1, 0), content="true")
  inspect(expr.matches(15, 12, 1, 1, 0), content="true")
  inspect(expr.matches(30, 12, 1, 1, 0), content="true")
  inspect(expr.matches(45, 12, 1, 1, 0), content="true")
  inspect(expr.matches(10, 12, 1, 1, 0), content="false")
}

///|
test "parse_cron with list" {
  // At minutes 0, 15, 30, 45: 0,15,30,45 * * * *
  let expr = @scheduler.parse_cron("0,15,30,45 * * * *")
  inspect(expr.matches(0, 12, 1, 1, 0), content="true")
  inspect(expr.matches(15, 12, 1, 1, 0), content="true")
  inspect(expr.matches(30, 12, 1, 1, 0), content="true")
  inspect(expr.matches(45, 12, 1, 1, 0), content="true")
  inspect(expr.matches(10, 12, 1, 1, 0), content="false")
}

///|
test "parse_cron with day_of_week" {
  // Every Monday at 9:00: 0 9 * * 1
  let expr = @scheduler.parse_cron("0 9 * * 1")
  // Monday (1) at 9:00
  inspect(expr.matches(0, 9, 1, 1, 1), content="true")
  // Tuesday (2) at 9:00 - should fail
  inspect(expr.matches(0, 9, 1, 1, 2), content="false")
  // Monday at 10:00 - should fail
  inspect(expr.matches(0, 10, 1, 1, 1), content="false")
}

///|
test "parse_cron error on invalid field count" {
  // Only 4 fields instead of 5
  let result : Result[@scheduler.CronExpression, @scheduler.CronParseError] = try? @scheduler.parse_cron(
    "* * * *",
  )
  inspect(result is Err(_), content="true")
}

///|
test "parse_cron error on invalid value" {
  // Minute 60 is out of range (0-59)
  let result : Result[@scheduler.CronExpression, @scheduler.CronParseError] = try? @scheduler.parse_cron(
    "60 * * * *",
  )
  inspect(result is Err(_), content="true")
}

///|
test "CronExpression::matches_timestamp" {
  // Every minute at hour 12: * 12 * * *
  let expr = @scheduler.parse_cron("* 12 * * *")

  // time_of_day = 12*3600 + 30*60 = 45000 seconds from midnight
  // minute = 45000 % 3600 / 60 = 1800 / 60 = 30
  // hour = 45000 / 3600 = 12
  let timestamp : Int64 = 45000L
  inspect(expr.matches_timestamp(timestamp), content="true")

  // 9:30 - hour 9 doesn't match
  let timestamp_9 : Int64 = 9L * 3600L + 30L * 60L // 34200
  inspect(expr.matches_timestamp(timestamp_9), content="false")
}

///|
test "ScheduledTask::new creates task" {
  let task = @scheduler.ScheduledTask::new(
    id="task_1",
    name="Test Task",
    cron_expr="* * * * *",
    payload=Json::string("test"),
  )
  inspect(task.id, content="task_1")
  inspect(task.name, content="Test Task")
  inspect(task.enabled, content="true")
}

///|
test "ScheduledTask::new with invalid cron fails" {
  let result : Result[@scheduler.ScheduledTask, @scheduler.CronParseError] = try? @scheduler.ScheduledTask::new(
    id="task_1",
    name="Test Task",
    cron_expr="invalid",
    payload=Json::null(),
  )
  inspect(result is Err(_), content="true")
}

///|
test "TaskScheduler::new creates empty scheduler" {
  let scheduler = @scheduler.TaskScheduler::new()
  let tasks = scheduler.get_all_tasks()
  inspect(tasks.length(), content="0")
}

///|
test "TaskScheduler::register adds task" {
  let scheduler = @scheduler.TaskScheduler::new()
  let task = @scheduler.ScheduledTask::new(
    id="task_1",
    name="Test Task",
    cron_expr="* * * * *",
    payload=Json::null(),
  )
  scheduler.register(task)
  let tasks = scheduler.get_all_tasks()
  inspect(tasks.length(), content="1")
}

///|
test "TaskScheduler::unregister removes task" {
  let scheduler = @scheduler.TaskScheduler::new()
  let task = @scheduler.ScheduledTask::new(
    id="task_1",
    name="Test Task",
    cron_expr="* * * * *",
    payload=Json::null(),
  )
  scheduler.register(task)
  inspect(scheduler.get_all_tasks().length(), content="1")
  let removed = scheduler.unregister("task_1")
  inspect(removed, content="true")
  inspect(scheduler.get_all_tasks().length(), content="0")

  // Try to remove non-existent task
  let not_found = scheduler.unregister("nonexistent")
  inspect(not_found, content="false")
}

///|
test "TaskScheduler::due_tasks returns matching tasks" {
  let scheduler = @scheduler.TaskScheduler::new()

  // Task that runs every minute at every hour (wildcard)
  let task1 = @scheduler.ScheduledTask::new(
    id="every_minute",
    name="Every Minute",
    cron_expr="* * * * *",
    payload=Json::null(),
  )

  // Task that runs only at minute 30, any hour
  let task2 = @scheduler.ScheduledTask::new(
    id="at_30",
    name="At Minute 30",
    cron_expr="30 * * * *",
    payload=Json::null(),
  )
  scheduler.register(task1)
  scheduler.register(task2)

  // timestamp for 12:30:00 (time_of_day = 45000 seconds)
  // minute = 45000 % 3600 / 60 = 1800 / 60 = 30
  // hour = 45000 / 3600 = 12
  let timestamp : Int64 = 45000L
  let due = scheduler.due_tasks(timestamp)

  // Both tasks should be due at minute 30 (task1 matches *, task2 matches 30)
  inspect(due.length(), content="2")
}

///|
test "TaskScheduler::due_tasks only returns enabled tasks" {
  let scheduler = @scheduler.TaskScheduler::new()
  let task = @scheduler.ScheduledTask::new(
    id="test",
    name="Test",
    cron_expr="* * * * *",
    payload=Json::null(),
  )

  // Disable the task
  task.enabled = false
  scheduler.register(task)
  let timestamp : Int64 = 45000L
  let due = scheduler.due_tasks(timestamp)

  // Task is disabled, should not be due
  inspect(due.length(), content="0")
}

// =============================================================================
// Persistence Tests
// =============================================================================

///|
test "task_to_json serializes task" {
  let task = @scheduler.ScheduledTask::new(
    id="t1",
    name="Test",
    cron_expr="30 10 * * *",
    payload=Json::string("hello"),
  )
  let json = @scheduler.task_to_json(task)
  match json {
    { "id": String("t1"), "name": String("Test"), "cron": String(cron), .. } =>
      inspect(cron.contains("30"), content="true")
    _ => fail("Expected task JSON")
  }
}

///|
test "task_from_json deserializes task" {
  let json : Json = {
    "id": "t1",
    "name": "Test",
    "cron": "30 10 * * *",
    "next_run": 0,
    "enabled": true,
    "payload": "hello",
  }
  match @scheduler.task_from_json(json) {
    Some(task) => {
      inspect(task.id, content="t1")
      inspect(task.name, content="Test")
      inspect(task.enabled, content="true")
    }
    None => fail("Expected Some")
  }
}

///|
test "scheduler_to_json and scheduler_from_json roundtrip" {
  let scheduler = @scheduler.TaskScheduler::new()
  let task = @scheduler.ScheduledTask::new(
    id="rt1",
    name="Roundtrip",
    cron_expr="0 9 * * 1",
    payload={ "key": "value" },
  )
  scheduler.register(task)
  let json = @scheduler.scheduler_to_json(scheduler)
  let restored = @scheduler.scheduler_from_json(json)
  let tasks = restored.get_all_tasks()
  inspect(tasks.length(), content="1")
  inspect(tasks[0].id, content="rt1")
}

// =============================================================================
// Heartbeat Runner Tests
// =============================================================================

///|
test "parse_heartbeat_tasks extracts checked and unchecked" {
  let content = "# Tasks\n\n- [ ] Unchecked task\n- [x] Checked task\n- [ ] Another unchecked"
  let tasks = @scheduler.parse_heartbeat_tasks(content)
  inspect(tasks.length(), content="3")
  inspect(tasks[0].0, content="Unchecked task")
  inspect(tasks[0].1, content="false")
  inspect(tasks[1].0, content="Checked task")
  inspect(tasks[1].1, content="true")
}

///|
test "get_pending_heartbeat_tasks returns only unchecked" {
  let content = "- [ ] Task A\n- [x] Task B\n- [ ] Task C"
  let pending = @scheduler.get_pending_heartbeat_tasks(content)
  inspect(pending.length(), content="2")
  inspect(pending[0], content="Task A")
  inspect(pending[1], content="Task C")
}

///|
test "build_heartbeat_prompt formats pending tasks" {
  let pending = ["Check server", "Review logs"]
  let prompt = @scheduler.build_heartbeat_prompt(pending)
  inspect(prompt.contains("Check server"), content="true")
  inspect(prompt.contains("Review logs"), content="true")
}

///|
test "cron roundtrip preserves specific values" {
  let scheduler = @scheduler.TaskScheduler::new()
  let task = @scheduler.ScheduledTask::new(
    id="specific",
    name="Specific Time",
    cron_expr="30 10 15 6 1",
    payload=Json::string("monthly"),
  )
  scheduler.register(task)
  let json = @scheduler.scheduler_to_json(scheduler)
  let restored = @scheduler.scheduler_from_json(json)
  let tasks = restored.get_all_tasks()
  inspect(tasks.length(), content="1")
  // 元の cron 式で同じ時刻がマッチするか検証
  inspect(tasks[0].cron.matches(30, 10, 15, 6, 1), content="true")
  inspect(tasks[0].cron.matches(0, 10, 15, 6, 1), content="false")
}

///|
test "task_from_json returns None for invalid json" {
  let json : Json = { "name": "no-id" }
  inspect(@scheduler.task_from_json(json) is None, content="true")
}

///|
test "build_heartbeat_prompt handles empty" {
  let pending : Array[String] = []
  let prompt = @scheduler.build_heartbeat_prompt(pending)
  inspect(prompt.contains("No pending"), content="true")
}
