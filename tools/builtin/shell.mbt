///|
/// シェルツール - コマンド実行（JS環境用実行コード）

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
