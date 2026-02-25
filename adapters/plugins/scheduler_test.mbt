///|
test "schedule_once creates task" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  match plugin.schedule_once("test_task", "my_method", None, 1000L) {
    Some(id) => inspect(id.has_prefix("task_"), content="true")
    None => fail("Expected task ID")
  }
}

///|
test "cancel sets task status" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  match plugin.schedule_once("test", "method", None, 1000L) {
    Some(id) => {
      inspect(plugin.cancel(id), content="true")
      // list_pending returns only pending tasks (not cancelled)
      inspect(plugin.list_pending().length(), content="0")
    }
    None => fail("Expected task ID")
  }
}

///|
test "list_tasks returns all" {
  let config = SchedulerPluginConfig::default(name="test")
  let plugin = SchedulerPlugin::new(config)
  let _ = plugin.schedule_once("task1", "m1", None, 1000L)
  let _ = plugin.schedule_once("task2", "m2", None, 2000L)
  inspect(plugin.list_tasks().length(), content="2")
}
