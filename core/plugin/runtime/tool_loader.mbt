///|
/// Native Tool Loader I/O
/// File operations for loading user-defined tools from {data_dir}/tools/

///|
/// Get tools directory path
fn get_tools_dir() -> String {
  @config.data_dir() + "/tools"
}

///|
/// Read file content as Option (None if file doesn't exist or error)
fn read_file_optional(path : String) -> String? {
  let content = @native.native_read_file_text(path) catch { _ => return None }
  Some(content)
}

///|
/// Create native tool loader I/O interface
pub fn create_tool_loader_io() -> @tool.ToolLoaderIO {
  {
    list_tool_dirs: fn() {
      let tools_dir = get_tools_dir()
      let dirs : Array[String] = []
      // Create tools directory if it doesn't exist (@native.dir_permission = 0o755)
      let _ = @native.c_mkdir_recursive_bytes(
        @native.string_to_utf8_cstring(tools_dir),
        @native.dir_permission,
      )
      // List subdirectories (entries that have a tool.json file inside)
      let entries = @native.native_list_dir_entries(tools_dir)
      for entry in entries {
        if not(entry.has_prefix(".")) {
          // Check if tool.json exists in this subdirectory
          let manifest_path = tools_dir + "/" + entry + "/tool.json"
          if @native.c_access_bytes(@native.string_to_utf8_cstring(manifest_path), @native.f_ok) == 0 {
            dirs.push(entry)
          }
        }
      }
      dirs
    },
    read_manifest: fn(tool_dir) {
      let manifest_path = get_tools_dir() + "/" + tool_dir + "/tool.json"
      read_file_optional(manifest_path)
    },
  }
}

///|
/// Load all user-defined tools using native I/O
pub fn load_native_user_defined_tools() -> Array[@interfaces.ToolState] {
  @tool.load_user_defined_tools(create_tool_loader_io())
}
