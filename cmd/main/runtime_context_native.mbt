///|
/// Workspace由来コンテキスト注入（Native専用）

///|
struct WorkspaceContextDirCell {
  // None = use @config.data_dir() dynamically
  // Some(path) = use custom path (set via set_workspace_context_dir_for_process)
  mut custom_path : String?
}

///|
let workspace_context_dir_cell : WorkspaceContextDirCell = { custom_path: None }

///|
pub fn set_workspace_context_dir_for_process(path : String) -> Unit {
  workspace_context_dir_cell.custom_path = Some(path)
}

///|
/// Get current workspace context directory
/// Uses @config.data_dir() dynamically to respect --data-dir flag
pub fn get_workspace_context_dir() -> String {
  match workspace_context_dir_cell.custom_path {
    Some(path) => path
    None => @config.data_dir()
  }
}

///|
fn context_path(file : String) -> String {
  get_workspace_context_dir() + "/" + file
}

///|
fn read_text_file_optional(path : String) -> String? {
  let content = @native.native_read_file_text(path) catch { _ => return None }
  Some(content)
}

///|
fn memory_json_from_lines(content : String) -> Json {
  let lines = content.split("\n")
  let values : Array[Json] = []
  for line in lines {
    let trimmed = line.trim()
    if trimmed.length() > 0 {
      values.push(Json::string(trimmed.to_string()))
    }
  }
  Json::array(values)
}

///|
/// 空でないファイルを読み込むヘルパー
fn read_non_empty_file(path : String) -> String? {
  match read_text_file_optional(path) {
    Some(content) =>
      if content.trim(chars=" \t\n\r").length() > 0 {
        Some(content)
      } else {
        None
      }
    None => None
  }
}

///|
/// コンテキストファイル（SOUL.md等）を読み込む
fn load_context_files(metadata : Map[String, Json]) -> Unit {
  // SOUL.md - AIの性格・価値観定義
  match read_non_empty_file(context_path("SOUL.md")) {
    Some(content) => metadata["soul"] = Json::string(content)
    None => ()
  }
  // AGENTS.md - ワークスペースハンドブック/行動指針
  match read_non_empty_file(context_path("AGENTS.md")) {
    Some(content) => metadata["agents_handbook"] = Json::string(content)
    None => ()
  }
  // TOOLS.md - ローカル環境・ツール設定
  match read_non_empty_file(context_path("TOOLS.md")) {
    Some(content) => metadata["tools_config"] = Json::string(content)
    None => ()
  }
  // IDENTITY.md - AIの名前・アイデンティティ
  match read_non_empty_file(context_path("IDENTITY.md")) {
    Some(content) => metadata["identity"] = Json::string(content)
    None => ()
  }
  // USER.md - ユーザー情報・好み
  match read_non_empty_file(context_path("USER.md")) {
    Some(content) => metadata["user_context"] = Json::string(content)
    None => ()
  }
}

///|
fn build_workspace_context_metadata() -> Map[String, Json] {
  let metadata : Map[String, Json] = {}
  match read_text_file_optional(context_path("bootstrap.md")) {
    Some(content) =>
      if content.trim().length() > 0 {
        metadata["bootstrap"] = Json::string(content)
      }
    None => ()
  }

  let load_memory_from_text = fn() {
    match read_text_file_optional(context_path("memory.txt")) {
      Some(lines) => {
        let line_values = memory_json_from_lines(lines)
        match line_values {
          Array(values) =>
            if values.length() > 0 {
              metadata["memory_context"] = line_values
            }
          _ => ()
        }
      }
      None => ()
    }
  }

  match read_text_file_optional(context_path("memory.json")) {
    Some(content) => {
      let parsed : Json = @json.parse(content) catch { _ => Json::null() }
      match parsed {
        Array(_) => metadata["memory_context"] = parsed
        _ => load_memory_from_text()
      }
    }
    None => load_memory_from_text()
  }

  match read_text_file_optional(context_path("skills.json")) {
    Some(content) => {
      let parsed : Json = @json.parse(content) catch { _ => Json::null() }
      match parsed {
        Array(_) => metadata["skills"] = parsed
        _ => ()
      }
    }
    None => ()
  }
  // コンテキストファイル（SOUL.md, AGENTS.md等）を読み込み
  load_context_files(metadata)
  metadata
}

///|
pub fn enrich_envelope_with_workspace_context_impl(
  envelope : @types.InboundEnvelope,
) -> @types.InboundEnvelope {
  let workspace_context = build_workspace_context_metadata()
  if workspace_context.is_empty() {
    return envelope
  }
  let merged_metadata : Map[String, Json] = envelope.metadata
  for key, value in workspace_context {
    if !merged_metadata.contains(key) {
      merged_metadata[key] = value
    }
  }
  { ..envelope, metadata: merged_metadata }
}
