///|
/// Native専用: OS標準ディレクトリ解決実装

///|
/// OS種別を判定
fn detect_os_impl() -> OsKind {
  let buffer_len = 64
  let buffer = Bytes::new(buffer_len)
  let read_len = c_get_os_name(buffer, buffer_len)
  if read_len <= 0 {
    return OsKind::Unknown
  }
  let os_name = @utf8.decode(buffer[:read_len]) catch {
    _ => return OsKind::Unknown
  }
  if os_name == "Darwin" {
    OsKind::MacOS
  } else if os_name == "Linux" {
    OsKind::Linux
  } else if os_name.contains("MINGW") ||
    os_name.contains("MSYS") ||
    os_name.contains("Windows") {
    OsKind::Windows
  } else {
    OsKind::Unknown
  }
}

///|
/// ホームディレクトリを取得
fn home_dir_impl() -> String {
  let buffer_len = 1024
  let buffer = Bytes::new(buffer_len)
  let read_len = c_get_home_dir(buffer, buffer_len)
  if read_len <= 0 {
    return ""
  }
  @utf8.decode(buffer[:read_len]) catch {
    _ => ""
  }
}

///|
/// 環境変数を取得
fn get_env(name : String) -> String? {
  let buffer_len = 4096
  let buffer = Bytes::new(buffer_len)
  let name_c = @bytes.to_utf8_cstring(name)
  let read_len = c_getenv_safe(name_c, buffer, buffer_len)
  if read_len <= 0 {
    return None
  }
  @bytes.decode_utf8(buffer[:read_len])
}

///|
/// OS標準の設定ディレクトリを取得
fn config_dir_impl() -> String {
  let home = home_dir_impl()
  match detect_os_impl() {
    Linux => {
      let xdg = get_env("XDG_CONFIG_HOME")
      match xdg {
        Some(v) if not(v.is_empty()) => v
        _ => if home.is_empty() { ".config" } else { home + "/.config" }
      }
    }
    MacOS =>
      if home.is_empty() {
        "Library/Application Support"
      } else {
        home + "/Library/Application Support"
      }
    Windows => {
      let appdata = get_env("APPDATA")
      match appdata {
        Some(v) if not(v.is_empty()) => v
        _ =>
          if home.is_empty() {
            "AppData/Roaming"
          } else {
            home + "/AppData/Roaming"
          }
      }
    }
    Unknown => if home.is_empty() { "." } else { home }
  }
}

///|
/// OS標準のデータディレクトリを取得
fn data_dir_impl() -> String {
  let home = home_dir_impl()
  match detect_os_impl() {
    Linux => {
      let xdg = get_env("XDG_DATA_HOME")
      match xdg {
        Some(v) if not(v.is_empty()) => v
        _ =>
          if home.is_empty() {
            ".local/share"
          } else {
            home + "/.local/share"
          }
      }
    }
    MacOS =>
      if home.is_empty() {
        "Library/Application Support"
      } else {
        home + "/Library/Application Support"
      }
    Windows => {
      let appdata = get_env("APPDATA")
      match appdata {
        Some(v) if not(v.is_empty()) => v
        _ =>
          if home.is_empty() {
            "AppData/Roaming"
          } else {
            home + "/AppData/Roaming"
          }
      }
    }
    Unknown => if home.is_empty() { "." } else { home }
  }
}

///|
/// OS標準のキャッシュ/ランタイムディレクトリを取得
fn cache_dir_impl() -> String {
  let home = home_dir_impl()
  match detect_os_impl() {
    Linux => {
      // Prefer XDG_RUNTIME_DIR for sockets/pids
      let runtime = get_env("XDG_RUNTIME_DIR")
      match runtime {
        Some(v) if not(v.is_empty()) => v
        _ => {
          let cache = get_env("XDG_CACHE_HOME")
          match cache {
            Some(v) if not(v.is_empty()) => v
            _ => if home.is_empty() { ".cache" } else { home + "/.cache" }
          }
        }
      }
    }
    MacOS =>
      if home.is_empty() {
        "Library/Caches"
      } else {
        home + "/Library/Caches"
      }
    Windows => {
      let localappdata = get_env("LOCALAPPDATA")
      match localappdata {
        Some(v) if not(v.is_empty()) => v
        _ =>
          if home.is_empty() {
            "AppData/Local"
          } else {
            home + "/AppData/Local"
          }
      }
    }
    Unknown => if home.is_empty() { "." } else { home }
  }
}

///|
/// OS標準の一時ディレクトリを取得
fn temp_dir_impl() -> String {
  match detect_os_impl() {
    Linux | MacOS => {
      let tmpdir = get_env("TMPDIR")
      match tmpdir {
        Some(v) if not(v.is_empty()) =>
          // TMPDIR may have trailing slash, normalize it
          if v.length() > 1 && v[v.length() - 1] == '/' {
            let trimmed : String = v[:v.length() - 1].to_string() catch { _ => v }
            trimmed
          } else {
            v
          }
        _ => "/tmp"
      }
    }
    Windows => {
      // Try TEMP first, then TMP
      let temp = get_env("TEMP")
      match temp {
        Some(v) if not(v.is_empty()) => v
        _ => {
          let tmp = get_env("TMP")
          match tmp {
            Some(v) if not(v.is_empty()) => v
            _ => "C:\\Windows\\Temp"
          }
        }
      }
    }
    Unknown => "/tmp"
  }
}

///|
/// HOME環境変数を取得してバッファに書き込む
#borrow(buffer)
extern "C" fn c_get_home_dir(buffer : Bytes, buffer_len : Int) -> Int = "moonbit_get_home_dir"

///|
/// OS名を取得してバッファに書き込む
#borrow(buffer)
extern "C" fn c_get_os_name(buffer : Bytes, buffer_len : Int) -> Int = "moonbit_get_os_name"

///|
/// 環境変数を取得してバッファに書き込む
#borrow(name, buffer)
extern "C" fn c_getenv_safe(
  name : Bytes,
  buffer : Bytes,
  buffer_len : Int,
) -> Int = "moonbit_getenv_safe"
