///|
/// スキル定義ローダー — skills/ ディレクトリから Markdown+YAML frontmatter を読み込み

///|
/// Markdown ファイルから YAML frontmatter + 本文を抽出
/// フォーマット: ---\nkey: value\n---\n(body)
pub fn parse_skill_markdown(
  content : String,
) -> @interfaces.SkillDefinition? {
  let lines = content.split("\n").collect()
  if lines.length() < 3 {
    return None
  }
  // 最初の行が --- でなければ frontmatter なし
  if lines[0].to_string().trim(chars=" \t\r\n").to_string() != "---" {
    return None
  }
  // 2つ目の --- を探す
  let mut end_idx = -1
  for i = 1; i < lines.length(); i = i + 1 {
    if lines[i].to_string().trim(chars=" \t\r\n").to_string() == "---" {
      end_idx = i
      break
    }
  }
  if end_idx < 0 {
    return None
  }
  // frontmatter パース (簡易 key: value)
  let mut name = ""
  let mut description = ""
  for i = 1; i < end_idx; i = i + 1 {
    let line = lines[i].to_string()
    let colon_idx = find_char_in_string(line, ':')
    if colon_idx > 0 {
      let key = line[:colon_idx].to_string().trim(chars=" \t").to_string()
      let value = line[colon_idx + 1:].to_string().trim(chars=" \t\r\n").to_string()
      match key {
        "name" => name = value
        "description" => description = value
        _ => ()
      }
    }
  }
  if name.is_empty() {
    return None
  }
  // 本文 (frontmatter の後)
  let body_buf = StringBuilder::new()
  for i = end_idx + 1; i < lines.length(); i = i + 1 {
    if i > end_idx + 1 {
      body_buf.write_char('\n')
    }
    body_buf.write_string(lines[i].to_string())
  }
  let instructions = body_buf.to_string().trim(chars=" \t\r\n").to_string()
  let skill : @interfaces.SkillDefinition = { name, description, instructions }
  Some(skill)
}

///|
/// 文字列内の文字位置を検索
fn find_char_in_string(s : String, target : Char) -> Int {
  let mut i = 0
  for c in s {
    if c == target {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// skills/ ディレクトリから全スキルを読み込んで SkillLoader に登録
pub fn load_skills_into_loader(
  skill_loader : SkillLoader,
  skills_dir : String,
) -> Unit {
  // ディレクトリ内の .md ファイルを列挙
  let files = list_skill_files(skills_dir)
  for file_path in files {
    let content = read_skill_file(file_path)
    match content {
      Some(text) =>
        match parse_skill_markdown(text) {
          Some(skill) => skill_loader.register(skill)
          None => ()
        }
      None => ()
    }
  }
}

///|
#borrow(path, buffer)
extern "C" fn skill_list_dir(
  path : Bytes,
  buffer : Bytes,
  buffer_len : Int,
) -> Int = "moonbit_list_dir"

///|
/// skills ディレクトリの .md ファイル一覧を取得
fn list_skill_files(dir : String) -> Array[String] {
  let dir_bytes = skill_to_cstr(dir)
  let buffer = Bytes::new(8192)
  let bytes_written = skill_list_dir(dir_bytes, buffer, 8192)
  if bytes_written <= 0 {
    return []
  }
  let entries = @bytes.parse_utf16le_lines(buffer, bytes_written)
  let result : Array[String] = []
  for entry in entries {
    if entry.has_suffix(".md") {
      result.push(dir + "/" + entry)
    }
  }
  result
}

///|
#borrow(path, mode)
extern "C" fn skill_fopen(path : Bytes, mode : Bytes) -> Int64 = "moonbit_fopen_bytes"

///|
#borrow(buffer)
extern "C" fn skill_fread(
  buffer : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fread_handle"

///|
extern "C" fn skill_fclose(handle : Int64) -> Int = "moonbit_fclose_handle"

///|
fn skill_to_cstr(s : String) -> Bytes {
  @bytes.to_utf8_cstring(s)
}

///|
/// スキルファイルを読み込み
fn read_skill_file(path : String) -> String? {
  let path_bytes = skill_to_cstr(path)
  let mode_bytes = skill_to_cstr("rb")
  let handle = skill_fopen(path_bytes, mode_bytes)
  if handle == 0L {
    return None
  }
  let buffer = Bytes::new(65536)
  let bytes_read = skill_fread(buffer, 1, 65536, handle)
  let _ = skill_fclose(handle)
  if bytes_read <= 0 {
    return None
  }
  @bytes.decode_utf8(buffer[:bytes_read])
}
