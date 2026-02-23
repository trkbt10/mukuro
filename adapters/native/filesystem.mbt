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
) -> String {
  match self.base_dir {
    Some(base) => if path.has_prefix("/") { path } else { "\{base}/\{path}" }
    None => path
  }
}

///|
pub impl @interfaces.FileStore for NativeFileStore with read_file(self, path~) {
  let resolved = self.resolve_path(path)
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
      // サブセットを取得
      if bytes_read < buffer_size {
        Bytes::from_iter(buffer.sub(end=bytes_read).iter())
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
  let resolved = self.resolve_path(path)
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
  let resolved = self.resolve_path(path)
  c_access(string_to_cstring(resolved), f_ok) == 0
}

///|
pub impl @interfaces.FileStore for NativeFileStore with remove_file(self, path~) {
  let resolved = self.resolve_path(path)
  let result = c_remove(string_to_cstring(resolved))
  if result != 0 {
    raise FileSystemError::IoError("Cannot remove file: \{resolved}")
  }
}

///|
pub impl @interfaces.FileStore for NativeFileStore with create_dir(self, path~) {
  let resolved = self.resolve_path(path)
  let result = c_mkdir(string_to_cstring(resolved), 493)
  if result != 0 {
    raise FileSystemError::IoError("Cannot create directory: \{resolved}")
  }
}

///|
pub impl @interfaces.FileStore for NativeFileStore with list_dir(self, path~) {
  let resolved = self.resolve_path(path)
  let command = "ls -1 '\{resolved}' 2>/dev/null"
  match c_popen(string_to_cstring(command), string_to_cstring("r")) {
    Some(pipe) => {
      let buffer = Bytes::new(4096)
      let bytes_read = c_fread(buffer, 1, 4096, pipe)
      let _ = c_pclose(pipe)
      if bytes_read <= 0 {
        return []
      }
      let output_bytes = Bytes::from_iter(buffer.sub(end=bytes_read).iter())
      let output = output_bytes.to_unchecked_string()
      let result : Array[String] = []
      for line in output.split("\n") {
        let s = line.to_string()
        if s.length() > 0 {
          result.push(s)
        }
      }
      result
    }
    None => raise FileSystemError::IoError("Cannot list directory: \{resolved}")
  }
}

///|
pub fn NativeFileStore::read_text(
  self : NativeFileStore,
  path : String,
) -> String raise FileSystemError {
  // Re-call the implementation directly to get correct error type
  let resolved = self.resolve_path(path)
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
        Bytes::from_iter(buffer.sub(end=bytes_read).iter()).to_unchecked_string()
      } else {
        buffer.to_unchecked_string()
      }
    }
    None => raise FileSystemError::FileNotFound(resolved)
  }
}
