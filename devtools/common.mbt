///|
/// 危険なコマンドかどうかをチェック
pub fn is_dangerous_command(command : String) -> Bool {
  let dangerous_patterns = [
    "rm -rf", "rm -r /", "dd if=", "mkfs", "> /dev/", "chmod -R 777",
    ":(){ :|:& };:",
  ]
  for pattern in dangerous_patterns {
    if command.contains(pattern) {
      return true
    }
  }
  false
}
