///|
/// Scheduler Plugin - Task Scheduling
/// Provides delayed execution, periodic tasks, and cron-like scheduling

///|
/// Scheduled task status
pub(all) enum TaskStatus {
  /// Task is pending execution
  Pending
  /// Task is currently running
  Running
  /// Task completed successfully
  Completed
  /// Task failed
  Failed(String)
  /// Task was cancelled
  Cancelled
}

///|
/// Scheduled task
pub(all) struct ScheduledTask {
  /// Unique task ID
  id : String
  /// Task name
  name : String
  /// JSON-RPC method to call when task fires
  rpc_method : String
  /// Parameters to pass to the method
  params : Json?
  /// Scheduled execution time (milliseconds since epoch)
  mut scheduled_at : Int64
  /// Repeat interval in milliseconds (0 = no repeat)
  repeat_interval_ms : Int64
  /// Maximum number of executions (0 = unlimited)
  max_executions : Int
  /// Number of times executed
  mut execution_count : Int
  /// Task status
  mut status : TaskStatus
  /// Created timestamp
  created_at : Int64
  /// Last executed timestamp
  mut last_executed_at : Int64?
}

///|
/// Scheduler plugin configuration
pub(all) struct SchedulerPluginConfig {
  /// Plugin name
  name : String
  /// Maximum number of tasks
  max_tasks : Int
  /// Default timeout for task execution (milliseconds)
  default_timeout_ms : Int64
}

///|
/// Default scheduler config
pub fn SchedulerPluginConfig::default(name~ : String) -> SchedulerPluginConfig {
  { name, max_tasks: 1000, default_timeout_ms: 30000L }
}

///|
/// Scheduler plugin
pub struct SchedulerPlugin {
  config : SchedulerPluginConfig
  /// All scheduled tasks
  tasks : Map[String, ScheduledTask]
  /// ID generator
  id_gen : @util.IdGenerator
  /// Current timestamp provider
  mut get_timestamp : () -> Int64
  /// Task execution callback
  mut on_task_execute : (ScheduledTask) -> Unit
}

///|
/// Create new scheduler plugin
pub fn SchedulerPlugin::new(config : SchedulerPluginConfig) -> SchedulerPlugin {
  {
    config,
    tasks: {},
    id_gen: @util.IdGenerator::new("task_"),
    get_timestamp: fn() { 0L },
    on_task_execute: fn(_task) { () },
  }
}

///|
/// Set timestamp provider
pub fn SchedulerPlugin::set_timestamp_provider(
  self : SchedulerPlugin,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Set task execution callback
pub fn SchedulerPlugin::set_on_execute(
  self : SchedulerPlugin,
  callback : (ScheduledTask) -> Unit,
) -> Unit {
  self.on_task_execute = callback
}

///|
/// Schedule a one-time task
pub fn SchedulerPlugin::schedule_once(
  self : SchedulerPlugin,
  name : String,
  rpc_method : String,
  params : Json?,
  delay_ms : Int64,
) -> String? {
  if self.tasks.length() >= self.config.max_tasks {
    return None
  }
  let now = (self.get_timestamp)()
  let id = self.id_gen.next()
  let task : ScheduledTask = {
    id,
    name,
    rpc_method,
    params,
    scheduled_at: now + delay_ms,
    repeat_interval_ms: 0L,
    max_executions: 1,
    execution_count: 0,
    status: TaskStatus::Pending,
    created_at: now,
    last_executed_at: None,
  }
  self.tasks[id] = task
  Some(id)
}

///|
/// Schedule a repeating task
pub fn SchedulerPlugin::schedule_repeat(
  self : SchedulerPlugin,
  name : String,
  rpc_method : String,
  params : Json?,
  interval_ms : Int64,
  max_executions? : Int = 0,
  initial_delay_ms? : Int64 = 0L,
) -> String? {
  if self.tasks.length() >= self.config.max_tasks {
    return None
  }
  let now = (self.get_timestamp)()
  let id = self.id_gen.next()
  let scheduled_at = if initial_delay_ms > 0L {
    now + initial_delay_ms
  } else {
    now + interval_ms
  }
  let task : ScheduledTask = {
    id,
    name,
    rpc_method,
    params,
    scheduled_at,
    repeat_interval_ms: interval_ms,
    max_executions,
    execution_count: 0,
    status: TaskStatus::Pending,
    created_at: now,
    last_executed_at: None,
  }
  self.tasks[id] = task
  Some(id)
}

///|
/// Cancel a scheduled task
pub fn SchedulerPlugin::cancel(
  self : SchedulerPlugin,
  task_id : String,
) -> Bool {
  match self.tasks.get(task_id) {
    Some(task) =>
      match task.status {
        TaskStatus::Pending | TaskStatus::Running => {
          task.status = TaskStatus::Cancelled
          true
        }
        _ => false
      }
    None => false
  }
}

///|
/// Get task by ID
pub fn SchedulerPlugin::get_task(
  self : SchedulerPlugin,
  task_id : String,
) -> ScheduledTask? {
  self.tasks.get(task_id)
}

///|
/// List all tasks
pub fn SchedulerPlugin::list_tasks(
  self : SchedulerPlugin,
) -> Array[ScheduledTask] {
  let result : Array[ScheduledTask] = []
  for _, task in self.tasks {
    result.push(task)
  }
  result
}

///|
/// List pending tasks
pub fn SchedulerPlugin::list_pending(
  self : SchedulerPlugin,
) -> Array[ScheduledTask] {
  let result : Array[ScheduledTask] = []
  for _, task in self.tasks {
    match task.status {
      TaskStatus::Pending => result.push(task)
      _ => ()
    }
  }
  result
}

///|
/// Get tasks ready for execution
pub fn SchedulerPlugin::get_ready_tasks(
  self : SchedulerPlugin,
) -> Array[ScheduledTask] {
  let now = (self.get_timestamp)()
  let ready : Array[ScheduledTask] = []
  for _, task in self.tasks {
    match task.status {
      TaskStatus::Pending => if task.scheduled_at <= now { ready.push(task) }
      _ => ()
    }
  }
  ready
}

///|
/// Execute ready tasks (called by scheduler loop)
pub fn SchedulerPlugin::tick(self : SchedulerPlugin) -> Array[ScheduledTask] {
  let now = (self.get_timestamp)()
  let executed : Array[ScheduledTask] = []
  for _, task in self.tasks {
    match task.status {
      TaskStatus::Pending =>
        if task.scheduled_at <= now {
          // Execute task
          task.status = TaskStatus::Running
          (self.on_task_execute)(task)
          task.execution_count = task.execution_count + 1
          task.last_executed_at = Some(now)
          // Check if task should repeat
          if task.repeat_interval_ms > 0L {
            let should_repeat = task.max_executions == 0 ||
              task.execution_count < task.max_executions
            if should_repeat {
              task.scheduled_at = now + task.repeat_interval_ms
              task.status = TaskStatus::Pending
            } else {
              task.status = TaskStatus::Completed
            }
          } else {
            task.status = TaskStatus::Completed
          }
          executed.push(task)
        }
      _ => ()
    }
  }
  executed
}

///|
/// Remove completed/cancelled tasks
pub fn SchedulerPlugin::cleanup(self : SchedulerPlugin) -> Int {
  let to_remove : Array[String] = []
  for id, task in self.tasks {
    match task.status {
      TaskStatus::Completed | TaskStatus::Cancelled | TaskStatus::Failed(_) =>
        to_remove.push(id)
      _ => ()
    }
  }
  for id in to_remove {
    self.tasks.remove(id)
  }
  to_remove.length()
}

///|
/// Handle JSON-RPC request
pub fn SchedulerPlugin::handle_request(
  self : SchedulerPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "schedule_once" => self.handle_schedule_once(request)
    "schedule_repeat" => self.handle_schedule_repeat(request)
    "cancel" => self.handle_cancel(request)
    "get_task" => self.handle_get_task(request)
    "list_tasks" => self.handle_list_tasks(request)
    "tick" => self.handle_tick(request)
    "cleanup" => self.handle_cleanup(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn SchedulerPlugin::handle_schedule_once(
  self : SchedulerPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (name, rpc_method, params, delay_ms) = match request.params {
    Some(
      { "name": String(n), "method": String(m), "delay_ms": Number(d, ..), .. } as p
    ) => {
      let params = match p {
        { "params": params, .. } => Some(params)
        _ => None
      }
      (n, m, params, d.to_int64())
    }
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing required parameters: name, method, delay_ms",
        id=request.id,
      )
  }
  match self.schedule_once(name, rpc_method, params, delay_ms) {
    Some(task_id) =>
      @interfaces.JsonRpcResponse::success(
        result={ "task_id": Json::string(task_id) },
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_internal_error(),
        message="Maximum tasks reached",
        id=request.id,
      )
  }
}

///|
fn SchedulerPlugin::handle_schedule_repeat(
  self : SchedulerPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (name, rpc_method, params, interval_ms, max_execs, initial_delay) = match
    request.params {
    Some(
      {
        "name": String(n),
        "method": String(m),
        "interval_ms": Number(i, ..),
        ..
      } as p
    ) => {
      let params = match p {
        { "params": params, .. } => Some(params)
        _ => None
      }
      let max_execs = match p {
        { "max_executions": Number(me, ..), .. } => me.to_int()
        _ => 0
      }
      let initial_delay = match p {
        { "initial_delay_ms": Number(id, ..), .. } => id.to_int64()
        _ => 0L
      }
      (n, m, params, i.to_int64(), max_execs, initial_delay)
    }
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing required parameters: name, method, interval_ms",
        id=request.id,
      )
  }
  match
    self.schedule_repeat(
      name,
      rpc_method,
      params,
      interval_ms,
      max_executions=max_execs,
      initial_delay_ms=initial_delay,
    ) {
    Some(task_id) =>
      @interfaces.JsonRpcResponse::success(
        result={ "task_id": Json::string(task_id) },
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_internal_error(),
        message="Maximum tasks reached",
        id=request.id,
      )
  }
}

///|
fn SchedulerPlugin::handle_cancel(
  self : SchedulerPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let task_id = match @interfaces.rpc_require_string(request, "task_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let cancelled = self.cancel(task_id)
  @interfaces.rpc_success_bool("cancelled", cancelled, request.id)
}

///|
fn SchedulerPlugin::handle_get_task(
  self : SchedulerPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let task_id = match @interfaces.rpc_require_string(request, "task_id") {
    Ok(id) => id
    Err(response) => return response
  }
  match self.get_task(task_id) {
    Some(task) =>
      @interfaces.JsonRpcResponse::success(
        result=task_to_json(task),
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Task not found",
        id=request.id,
      )
  }
}

///|
fn SchedulerPlugin::handle_list_tasks(
  self : SchedulerPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let tasks = self.list_tasks()
  @interfaces.rpc_success_array("tasks", tasks, task_to_json, request.id)
}

///|
fn SchedulerPlugin::handle_tick(
  self : SchedulerPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let executed = self.tick()
  let executed_json : Array[Json] = []
  for task in executed {
    executed_json.push(Json::string(task.id))
  }
  @interfaces.JsonRpcResponse::success(
    result={ "executed": Json::array(executed_json) },
    id=request.id,
  )
}

///|
fn SchedulerPlugin::handle_cleanup(
  self : SchedulerPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let removed = self.cleanup()
  @interfaces.JsonRpcResponse::success(
    result={ "removed": Json::number(removed.to_double()) },
    id=request.id,
  )
}

///|
fn task_to_json(task : ScheduledTask) -> Json {
  let status_str = match task.status {
    TaskStatus::Pending => "pending"
    TaskStatus::Running => "running"
    TaskStatus::Completed => "completed"
    TaskStatus::Failed(msg) => "failed: \{msg}"
    TaskStatus::Cancelled => "cancelled"
  }
  let obj : Map[String, Json] = {
    "id": Json::string(task.id),
    "name": Json::string(task.name),
    "method": Json::string(task.rpc_method),
    "scheduled_at": Json::number(task.scheduled_at.to_double()),
    "repeat_interval_ms": Json::number(task.repeat_interval_ms.to_double()),
    "execution_count": Json::number(task.execution_count.to_double()),
    "status": Json::string(status_str),
    "created_at": Json::number(task.created_at.to_double()),
  }
  match task.params {
    Some(p) => obj["params"] = p
    None => ()
  }
  match task.last_executed_at {
    Some(t) => obj["last_executed_at"] = Json::number(t.to_double())
    None => ()
  }
  Json::object(obj)
}
