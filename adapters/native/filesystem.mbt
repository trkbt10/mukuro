///|
/// Native FileSystem 実装
/// POSIX ファイルシステム API を使用

///|
pub(all) suberror FileSystemError {
  FileNotFound(String)
  PermissionDenied(String)
  IoError(String)
  InvalidPath(String)
}

///|
pub struct NativeFileStore {
  base_dir : String?
}

///|
pub fn NativeFileStore::new(base_dir~ : String?) -> NativeFileStore {
  { base_dir, }
}

///|
pub fn NativeFileStore::default() -> NativeFileStore {
  { base_dir: None }
}

///|
fn NativeFileStore::resolve_path(
  self : NativeFileStore,
  path : String,
) -> String raise FileSystemError {
  if path.contains("..") {
    raise FileSystemError::InvalidPath("Path traversal not allowed: \{path}")
  }
  match self.base_dir {
    Some(base) => if path.has_prefix("/") { path } else { "\{base}/\{path}" }
    None => path
  }
}

///|
pub impl @interfaces.FileStore for NativeFileStore with read_file(self, path~) {
  let resolved = self.resolve_path(path) catch {
    FileSystemError::InvalidPath(msg) => raise FileSystemError::InvalidPath(msg)
    e => raise e
  }
  native_read_file_bytes(resolved)
}

///|
pub impl @interfaces.FileStore for NativeFileStore with write_file(
  self,
  path~,
  data~,
) {
  let resolved = self.resolve_path(path) catch {
    FileSystemError::InvalidPath(msg) => raise FileSystemError::InvalidPath(msg)
    e => raise e
  }
  native_write_file_bytes(resolved, data)
}

///|
pub impl @interfaces.FileStore for NativeFileStore with exists(self, path~) {
  let resolved = self.resolve_path(path) catch { _ => return false }
  c_access(string_to_cstring(resolved), f_ok) == 0
}

///|
pub impl @interfaces.FileStore for NativeFileStore with remove_file(self, path~) {
  let resolved = self.resolve_path(path) catch {
    FileSystemError::InvalidPath(msg) => raise FileSystemError::InvalidPath(msg)
    e => raise e
  }
  let result = c_remove(string_to_cstring(resolved))
  if result != 0 {
    raise FileSystemError::IoError("Cannot remove file: \{resolved}")
  }
}

///|
pub impl @interfaces.FileStore for NativeFileStore with create_dir(self, path~) {
  let resolved = self.resolve_path(path) catch {
    FileSystemError::InvalidPath(msg) => raise FileSystemError::InvalidPath(msg)
    e => raise e
  }
  let result = c_mkdir(string_to_cstring(resolved), 493)
  if result != 0 {
    raise FileSystemError::IoError("Cannot create directory: \{resolved}")
  }
}

///|
pub impl @interfaces.FileStore for NativeFileStore with list_dir(self, path~) {
  let resolved = self.resolve_path(path) catch {
    FileSystemError::InvalidPath(msg) => raise FileSystemError::InvalidPath(msg)
    e => raise e
  }
  let entries = native_list_dir_entries(resolved)
  if entries.length() == 0 && c_access(string_to_cstring(resolved), f_ok) != 0 {
    raise FileSystemError::IoError("Cannot list directory: \{resolved}")
  }
  entries
}

///|
pub fn NativeFileStore::read_text(
  self : NativeFileStore,
  path : String,
) -> String raise FileSystemError {
  let resolved = self.resolve_path(path) catch { e => raise e }
  native_read_file_text(resolved)
}
