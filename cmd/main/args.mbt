///|
/// コマンドライン引数取得
/// @env.args() を使用（全ターゲット共通）

///|
/// 文字列が指定サフィックスで終わるかチェック
fn ends_with(s : String, suffix : String) -> Bool {
  let s_len = s.length()
  let suffix_len = suffix.length()
  if s_len < suffix_len {
    return false
  }
  let s_chars : Array[Char] = []
  let suffix_chars : Array[Char] = []
  for c in s {
    s_chars.push(c)
  }
  for c in suffix {
    suffix_chars.push(c)
  }
  for i in 0..<suffix_len {
    if s_chars[s_len - suffix_len + i] != suffix_chars[i] {
      return false
    }
  }
  true
}

///|
/// args[0]がNode.jsバイナリかどうかを判定
/// "node", "/node", "\\node", "node.exe" で終わる場合のみtrue
fn is_node_binary(path : String) -> Bool {
  // 完全一致: "node"
  if path == "node" {
    return true
  }
  // パス末尾: "/node" (Unix) または "\\node" (Windows)
  if ends_with(path, "/node") || ends_with(path, "\\node") {
    return true
  }
  // Windows実行ファイル: "node.exe"
  if ends_with(path, "node.exe") {
    return true
  }
  false
}

///|
/// Node.js環境かどうかを判定
/// args[0]がnodeバイナリ、または args[1]がJS拡張子で終わる
fn is_nodejs_environment(args : Array[String]) -> Bool {
  if args.is_empty() {
    return false
  }
  // args[0] がnodeバイナリ（/usr/bin/node, node.exe など）
  if is_node_binary(args[0]) {
    return true
  }
  // args[1] がJS系拡張子で終わる
  if args.length() > 1 {
    let script = args[1]
    if ends_with(script, ".js") ||
      ends_with(script, ".mjs") ||
      ends_with(script, ".cjs") {
      return true
    }
  }
  false
}

///|
/// コマンドライン引数を取得
/// Native: argv[0]（プログラム名）をスキップ
/// JS: argv[0]（node）とargv[1]（script）をスキップ
fn get_command_line_args() -> Array[String] {
  let all_args = @env.args()
  if all_args.is_empty() {
    return []
  }
  // スキップする数を判定
  // JS環境: process.argv = [node, script, ...args]
  // Native環境: argv = [program, ...args]
  let skip = if is_nodejs_environment(all_args) { 2 } else { 1 }
  let result : Array[String] = []
  for i in skip..<all_args.length() {
    result.push(all_args[i])
  }
  result
}
