///|
/// シェルツール - コマンド実行（Node.js環境用）

///|
/// シェルツール定義
pub fn shell_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="shell",
    description="Execute shell commands (requires Node.js environment)",
    parameters=object_schema(
      {
        "command": string_param("Command to execute", true),
        "cwd": string_param("Working directory", false),
        "timeout": integer_param("Timeout in milliseconds"),
        "env": { "type": "object", "description": "Environment variables" },
      },
      ["command"],
    ),
  )
}

///|
/// Node.js child_process.exec FFI型
#external
type JsChildProcess

///|
/// シェルコマンドを実行
extern "js" fn js_exec_command(
  command : String,
  cwd : String?,
  timeout : Int,
  on_success : (String, String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(command, cwd, timeout, onSuccess, onError) => {
  #|  if (typeof require === 'undefined') {
  #|    onError('Shell execution requires Node.js environment');
  #|    return;
  #|  }
  #|  const { exec } = require('child_process');
  #|  const options = { timeout: timeout || 30000 };
  #|  if (cwd) options.cwd = cwd;
  #|  exec(command, options, (error, stdout, stderr) => {
  #|    if (error) {
  #|      onError(error.message);
  #|    } else {
  #|      onSuccess(stdout, stderr);
  #|    }
  #|  });
  #|}

///|
/// シェルツールを実行（コールバックベース）
pub fn execute_shell_tool(
  args : Json,
  on_result : (ToolExecutionResult) -> Unit,
) -> Unit {
  let command = match get_string_arg(args, "command") {
    Some(c) => c
    None => {
      on_result(ToolExecutionResult::error("Missing command argument"))
      return
    }
  }
  let cwd = get_string_arg(args, "cwd")
  let timeout = get_int_arg(args, "timeout").unwrap_or(30000)
  // 危険なコマンドをチェック
  if is_dangerous_command(command) {
    on_result(
      ToolExecutionResult::requires_confirmation({
        "command": command,
        "warning": "This command may be destructive. Please confirm execution.",
      }),
    )
    return
  }
  js_exec_command(
    command,
    cwd,
    timeout,
    fn(stdout, stderr) {
      on_result(
        ToolExecutionResult::success({
          "stdout": stdout,
          "stderr": stderr,
          "exit_code": 0,
        }),
      )
    },
    fn(error) { on_result(ToolExecutionResult::error(error)) },
  )
}

///|
/// 危険なコマンドかどうかをチェック
pub fn is_dangerous_command(command : String) -> Bool {
  let dangerous_patterns = [
    "rm -rf", "rm -r /", "dd if=", "mkfs", "> /dev/", "chmod -R 777", ":(){ :|:& };:",
  ]
  for pattern in dangerous_patterns {
    if command.contains(pattern) {
      return true
    }
  }
  false
}
