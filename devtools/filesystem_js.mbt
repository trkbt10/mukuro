///|
/// ファイルシステムツール - ファイル操作（JS環境用実行コード）

///|
/// ファイル読み込み
extern "js" fn js_read_file(
  path : String,
  encoding : String,
  on_success : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(path, encoding, onSuccess, onError) => {
  #|  if (typeof require === 'undefined') {
  #|    onError('Filesystem operations require Node.js environment');
  #|    return;
  #|  }
  #|  const fs = require('fs');
  #|  fs.readFile(path, encoding || 'utf8', (err, data) => {
  #|    if (err) onError(err.message);
  #|    else onSuccess(data);
  #|  });
  #|}

///|
/// ファイル書き込み
extern "js" fn js_write_file(
  path : String,
  content : String,
  encoding : String,
  on_success : () -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(path, content, encoding, onSuccess, onError) => {
  #|  if (typeof require === 'undefined') {
  #|    onError('Filesystem operations require Node.js environment');
  #|    return;
  #|  }
  #|  const fs = require('fs');
  #|  fs.writeFile(path, content, encoding || 'utf8', (err) => {
  #|    if (err) onError(err.message);
  #|    else onSuccess();
  #|  });
  #|}

///|
/// ファイル追記
extern "js" fn js_append_file(
  path : String,
  content : String,
  encoding : String,
  on_success : () -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(path, content, encoding, onSuccess, onError) => {
  #|  if (typeof require === 'undefined') {
  #|    onError('Filesystem operations require Node.js environment');
  #|    return;
  #|  }
  #|  const fs = require('fs');
  #|  fs.appendFile(path, content, encoding || 'utf8', (err) => {
  #|    if (err) onError(err.message);
  #|    else onSuccess();
  #|  });
  #|}

///|
/// ファイル削除
extern "js" fn js_delete_file(
  path : String,
  recursive : Bool,
  on_success : () -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(path, recursive, onSuccess, onError) => {
  #|  if (typeof require === 'undefined') {
  #|    onError('Filesystem operations require Node.js environment');
  #|    return;
  #|  }
  #|  const fs = require('fs');
  #|  if (recursive) {
  #|    fs.rm(path, { recursive: true, force: true }, (err) => {
  #|      if (err) onError(err.message);
  #|      else onSuccess();
  #|    });
  #|  } else {
  #|    fs.unlink(path, (err) => {
  #|      if (err) onError(err.message);
  #|      else onSuccess();
  #|    });
  #|  }
  #|}

///|
/// ファイル存在確認
extern "js" fn js_file_exists(path : String) -> Bool =
  #|(path) => {
  #|  if (typeof require === 'undefined') return false;
  #|  const fs = require('fs');
  #|  return fs.existsSync(path);
  #|}

///|
/// ディレクトリ一覧
extern "js" fn js_list_dir(
  path : String,
  on_success : (Array[String]) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(path, onSuccess, onError) => {
  #|  if (typeof require === 'undefined') {
  #|    onError('Filesystem operations require Node.js environment');
  #|    return;
  #|  }
  #|  const fs = require('fs');
  #|  fs.readdir(path, (err, files) => {
  #|    if (err) onError(err.message);
  #|    else onSuccess(files);
  #|  });
  #|}

///|
/// ディレクトリ作成
extern "js" fn js_mkdir(
  path : String,
  recursive : Bool,
  on_success : () -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(path, recursive, onSuccess, onError) => {
  #|  if (typeof require === 'undefined') {
  #|    onError('Filesystem operations require Node.js environment');
  #|    return;
  #|  }
  #|  const fs = require('fs');
  #|  fs.mkdir(path, { recursive }, (err) => {
  #|    if (err) onError(err.message);
  #|    else onSuccess();
  #|  });
  #|}

///|
/// ファイル情報取得
extern "js" fn js_file_stat(
  path : String,
  on_success : (Json) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(path, onSuccess, onError) => {
  #|  if (typeof require === 'undefined') {
  #|    onError('Filesystem operations require Node.js environment');
  #|    return;
  #|  }
  #|  const fs = require('fs');
  #|  fs.stat(path, (err, stats) => {
  #|    if (err) onError(err.message);
  #|    else onSuccess({
  #|      size: stats.size,
  #|      isFile: stats.isFile(),
  #|      isDirectory: stats.isDirectory(),
  #|      created: stats.birthtime.toISOString(),
  #|      modified: stats.mtime.toISOString(),
  #|      accessed: stats.atime.toISOString(),
  #|    });
  #|  });
  #|}

///|
/// ファイルシステムツールを実行（コールバックベース）
pub fn execute_filesystem_tool(
  args : Json,
  on_result : (@defs.ToolExecutionResult) -> Unit,
) -> Unit {
  let action = match @defs.get_string_arg(args, "action") {
    Some(a) => a
    None => {
      on_result(@defs.ToolExecutionResult::error("Missing action argument"))
      return
    }
  }
  let path = match @defs.get_string_arg(args, "path") {
    Some(p) => p
    None => {
      on_result(@defs.ToolExecutionResult::error("Missing path argument"))
      return
    }
  }
  let encoding = @defs.get_string_arg(args, "encoding").unwrap_or("utf8")
  let recursive = @defs.get_bool_arg(args, "recursive").unwrap_or(false)
  match action {
    "read" =>
      js_read_file(
        path,
        encoding,
        fn(content) {
          on_result(
            @defs.ToolExecutionResult::success({
              "path": path,
              "content": content,
            }),
          )
        },
        fn(error) { on_result(@defs.ToolExecutionResult::error(error)) },
      )
    "write" => {
      let content = match @defs.get_string_arg(args, "content") {
        Some(c) => c
        None => {
          on_result(
            @defs.ToolExecutionResult::error("Missing content argument"),
          )
          return
        }
      }
      js_write_file(
        path,
        content,
        encoding,
        fn() {
          on_result(
            @defs.ToolExecutionResult::success({
              "path": path,
              "written": true,
            }),
          )
        },
        fn(error) { on_result(@defs.ToolExecutionResult::error(error)) },
      )
    }
    "append" => {
      let content = match @defs.get_string_arg(args, "content") {
        Some(c) => c
        None => {
          on_result(
            @defs.ToolExecutionResult::error("Missing content argument"),
          )
          return
        }
      }
      js_append_file(
        path,
        content,
        encoding,
        fn() {
          on_result(
            @defs.ToolExecutionResult::success({
              "path": path,
              "appended": true,
            }),
          )
        },
        fn(error) { on_result(@defs.ToolExecutionResult::error(error)) },
      )
    }
    "delete" =>
      js_delete_file(
        path,
        recursive,
        fn() {
          on_result(
            @defs.ToolExecutionResult::success({
              "path": path,
              "deleted": true,
            }),
          )
        },
        fn(error) { on_result(@defs.ToolExecutionResult::error(error)) },
      )
    "exists" => {
      let exists = js_file_exists(path)
      on_result(
        @defs.ToolExecutionResult::success({ "path": path, "exists": exists }),
      )
    }
    "list" =>
      js_list_dir(
        path,
        fn(files) {
          let files_json : Array[Json] = files.map(fn(f) { Json::string(f) })
          on_result(
            @defs.ToolExecutionResult::success({
              "path": path,
              "files": Json::array(files_json),
              "count": files.length(),
            }),
          )
        },
        fn(error) { on_result(@defs.ToolExecutionResult::error(error)) },
      )
    "mkdir" =>
      js_mkdir(
        path,
        recursive,
        fn() {
          on_result(
            @defs.ToolExecutionResult::success({
              "path": path,
              "created": true,
            }),
          )
        },
        fn(error) { on_result(@defs.ToolExecutionResult::error(error)) },
      )
    "stat" =>
      js_file_stat(
        path,
        fn(stat) { on_result(@defs.ToolExecutionResult::success(stat)) },
        fn(error) { on_result(@defs.ToolExecutionResult::error(error)) },
      )
    _ =>
      on_result(@defs.ToolExecutionResult::error("Unknown action: \{action}"))
  }
}
