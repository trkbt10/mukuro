///|
/// Scheduler Plugin Tests

///|
test "SchedulerPlugin::new creates empty plugin" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  inspect(plugin.tasks.length(), content="0")
}

///|
test "SchedulerPluginConfig::default" {
  let config = SchedulerPluginConfig::default(name="my-scheduler")
  inspect(config.name, content="my-scheduler")
  inspect(config.max_tasks, content="1000")
}

///|
test "SchedulerPlugin::schedule_once" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  plugin.set_timestamp_provider(fn() { 1000L })
  match plugin.schedule_once("task1", "do_something", None, 5000L) {
    Some(id) =>
      match plugin.get_task(id) {
        Some(task) => {
          inspect(task.name, content="task1")
          inspect(task.scheduled_at, content="6000")
        }
        None => fail("Expected to find task")
      }
    None => fail("Expected task to be scheduled")
  }
}

///|
test "SchedulerPlugin::schedule_repeat" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  plugin.set_timestamp_provider(fn() { 1000L })
  match
    plugin.schedule_repeat(
      "repeat_task",
      "do_repeat",
      None,
      10000L,
      max_executions=5,
    ) {
    Some(id) =>
      match plugin.get_task(id) {
        Some(task) => {
          inspect(task.name, content="repeat_task")
          inspect(task.repeat_interval_ms, content="10000")
          inspect(task.max_executions, content="5")
        }
        None => fail("Expected to find task")
      }
    None => fail("Expected task to be scheduled")
  }
}

///|
test "SchedulerPlugin::cancel" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  match plugin.schedule_once("cancel_me", "method", None, 5000L) {
    Some(id) => {
      inspect(plugin.cancel(id), content="true")
      match plugin.get_task(id) {
        Some(task) =>
          match task.status {
            TaskStatus::Cancelled => ()
            _ => fail("Expected cancelled status")
          }
        None => fail("Expected to find task")
      }
    }
    None => fail("Expected task to be scheduled")
  }
}

///|
test "SchedulerPlugin::list_tasks" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  let _ = plugin.schedule_once("task1", "method1", None, 1000L)
  let _ = plugin.schedule_once("task2", "method2", None, 2000L)
  let tasks = plugin.list_tasks()
  inspect(tasks.length(), content="2")
}

///|
test "SchedulerPlugin::list_pending" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  let _ = plugin.schedule_once("task1", "method1", None, 1000L)
  let pending = plugin.list_pending()
  inspect(pending.length(), content="1")
}

///|
test "SchedulerPlugin::get_ready_tasks" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  plugin.set_timestamp_provider(fn() { 1000L })
  let _ = plugin.schedule_once("early", "method", None, 0L) // scheduled at 1000
  let _ = plugin.schedule_once("later", "method", None, 5000L) // scheduled at 6000
  plugin.set_timestamp_provider(fn() { 2000L })
  let ready = plugin.get_ready_tasks()
  inspect(ready.length(), content="1")
}

///|
test "SchedulerPlugin::tick executes ready tasks" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  let mut executed_count = 0
  plugin.set_on_execute(fn(_task) { executed_count = executed_count + 1 })
  plugin.set_timestamp_provider(fn() { 1000L })
  let _ = plugin.schedule_once("task", "method", None, 0L)
  plugin.set_timestamp_provider(fn() { 2000L })
  let executed = plugin.tick()
  inspect(executed.length(), content="1")
  inspect(executed_count, content="1")
}

///|
test "SchedulerPlugin::tick repeating task" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  plugin.set_timestamp_provider(fn() { 1000L })
  let id = plugin.schedule_repeat(
    "repeat",
    "method",
    None,
    1000L,
    max_executions=3,
  )
  match id {
    Some(task_id) => {
      // First execution
      plugin.set_timestamp_provider(fn() { 3000L })
      let _ = plugin.tick()
      match plugin.get_task(task_id) {
        Some(task) => {
          inspect(task.execution_count, content="1")
          // Should be rescheduled
          match task.status {
            TaskStatus::Pending => ()
            _ => fail("Expected pending status after repeat")
          }
        }
        None => fail("Expected to find task")
      }
    }
    None => fail("Expected task to be scheduled")
  }
}

///|
test "SchedulerPlugin::cleanup" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  plugin.set_timestamp_provider(fn() { 1000L })
  let id = plugin.schedule_once("task", "method", None, 0L)
  match id {
    Some(_) => {
      plugin.set_timestamp_provider(fn() { 2000L })
      let _ = plugin.tick()
      let removed = plugin.cleanup()
      inspect(removed, content="1")
      inspect(plugin.tasks.length(), content="0")
    }
    None => fail("Expected task to be scheduled")
  }
}

///|
test "SchedulerPlugin::handle_request schedule_once" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "schedule_once",
    params: Some({ "name": "test_task", "method": "do_it", "delay_ms": 5000.0 }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "task_id": String(_), .. }) => ()
    _ => fail("Expected task_id result")
  }
}

///|
test "SchedulerPlugin::handle_request schedule_repeat" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "schedule_repeat",
    params: Some({
      "name": "repeat_task",
      "method": "do_repeat",
      "interval_ms": 10000.0,
      "max_executions": 5.0,
    }),
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "task_id": String(_), .. }) => ()
    _ => fail("Expected task_id result")
  }
}

///|
test "SchedulerPlugin::handle_request cancel" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  let id = plugin.schedule_once("task", "method", None, 5000L)
  match id {
    Some(task_id) => {
      let request : @interfaces.JsonRpcRequest = {
        jsonrpc: "2.0",
        rpc_method: "cancel",
        params: Some({ "task_id": task_id }),
        id: Some(1),
      }
      let response = plugin.handle_request(request)
      match response.result {
        Some({ "cancelled": True, .. }) => ()
        _ => fail("Expected cancelled: true")
      }
    }
    None => fail("Expected task to be scheduled")
  }
}

///|
test "SchedulerPlugin::handle_request list_tasks" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  let _ = plugin.schedule_once("t1", "m1", None, 1000L)
  let _ = plugin.schedule_once("t2", "m2", None, 2000L)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "list_tasks",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.result {
    Some({ "tasks": Array(arr), .. }) => inspect(arr.length(), content="2")
    _ => fail("Expected tasks array")
  }
}

///|
test "SchedulerPlugin::handle_request method not found" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  let request : @interfaces.JsonRpcRequest = {
    jsonrpc: "2.0",
    rpc_method: "unknown_method",
    params: None,
    id: Some(1),
  }
  let response = plugin.handle_request(request)
  match response.error {
    Some(err) => inspect(err.code, content="-32601")
    None => fail("Expected error response")
  }
}

///|
test "SchedulerPlugin max_tasks limit" {
  let config : SchedulerPluginConfig = {
    name: "test",
    max_tasks: 2,
    default_timeout_ms: 30000L,
  }
  let plugin = SchedulerPlugin::new(config)
  let _ = plugin.schedule_once("t1", "m1", None, 1000L)
  let _ = plugin.schedule_once("t2", "m2", None, 2000L)
  // Third task should fail
  inspect(plugin.schedule_once("t3", "m3", None, 3000L) is None, content="true")
}
