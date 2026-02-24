///|
/// Workspace由来コンテキスト注入（Native専用）

///|
struct WorkspaceContextDirCell {
  mut path : String
}

///|
let workspace_context_dir_cell : WorkspaceContextDirCell = { path: ".mukuro" }

///|
pub fn set_workspace_context_dir_for_process(path : String) -> Unit {
  workspace_context_dir_cell.path = path
}

///|
fn context_path(file : String) -> String {
  workspace_context_dir_cell.path + "/" + file
}

///|
fn read_text_file_optional(path : String) -> String? {
  let buffer_len = 131072
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file(
    @native.string_to_cstring(path),
    buffer,
    buffer_len,
  )
  if read_len <= 0 {
    return None
  }
  let data = Bytes::from_iter(buffer[:read_len].iter())
  let decoded = @utf8.decode(data[:]) catch { _ => return None }
  Some(decoded)
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
