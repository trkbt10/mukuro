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
  // Reject path traversal attempts
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
  let cpath = string_to_cstring(resolved)
  match c_fopen(cpath, string_to_cstring("rb")) {
    Some(file) => {
      let buffer_size = 65536
      let buffer = Bytes::new(buffer_size)
      let bytes_read = c_fread(buffer, 1, buffer_size, file)
      let _ = c_fclose(file)
      if bytes_read < 0 {
        raise FileSystemError::IoError("Read error: \{resolved}")
      }
      if bytes_read < buffer_size {
        @bytes.copy_slice(buffer[:bytes_read])
      } else {
        buffer
      }
    }
    None => raise FileSystemError::FileNotFound(resolved)
  }
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
  let cpath = string_to_cstring(resolved)
  match c_fopen(cpath, string_to_cstring("wb")) {
    Some(file) => {
      let bytes_written = c_fwrite(data, 1, data.length(), file)
      let _ = c_fclose(file)
      if bytes_written != data.length() {
        raise FileSystemError::IoError("Write error: \{resolved}")
      }
    }
    None =>
      raise FileSystemError::IoError(
        "Cannot open file for writing: \{resolved}",
      )
  }
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
  let buffer = Bytes::new(8192)
  let bytes_written = c_list_dir(string_to_cstring(resolved), buffer, 8192)
  if bytes_written < 0 {
    raise FileSystemError::IoError("Cannot list directory: \{resolved}")
  }
  if bytes_written == 0 {
    return []
  }
  @bytes.parse_utf16le_lines(buffer, bytes_written)
}

///|
pub fn NativeFileStore::read_text(
  self : NativeFileStore,
  path : String,
) -> String raise FileSystemError {
  // Re-call the implementation directly to get correct error type
  let resolved = self.resolve_path(path) catch { e => raise e }
  let cpath = string_to_cstring(resolved)
  match c_fopen(cpath, string_to_cstring("rb")) {
    Some(file) => {
      let buffer_size = 65536
      let buffer = Bytes::new(buffer_size)
      let bytes_read = c_fread(buffer, 1, buffer_size, file)
      let _ = c_fclose(file)
      if bytes_read < 0 {
        raise FileSystemError::IoError("Read error: \{resolved}")
      }
      @bytes.decode_utf8_or(buffer[:bytes_read], default="")
    }
    None => raise FileSystemError::FileNotFound(resolved)
  }
}
