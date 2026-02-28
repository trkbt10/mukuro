/// UTF-16LE バッファを改行区切りの文字列配列にパース
/// c_list_dir 出力の解析に使用
pub fn parse_utf16le_lines(buffer : Bytes, len : Int) -> Array[String] {
  let entries : Array[String] = []
  let current = StringBuilder::new()
  let mut i = 0
  while i + 1 < len {
    let lo = buffer[i].to_int()
    let hi = buffer[i + 1].to_int()
    let ch = (lo | (hi << 8)).unsafe_to_char()
    if ch == '\n' {
      let name = current.to_string()
      if name.length() > 0 {
        entries.push(name)
      }
      current.reset()
    } else {
      current.write_char(ch)
    }
    i = i + 2
  }
  // 末尾の改行なしエントリを処理
  let last = current.to_string()
  if last.length() > 0 {
    entries.push(last)
  }
  entries
}
