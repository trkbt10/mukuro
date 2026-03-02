///|
/// JS/WASM用スタブ: OS判定不可、カレントディレクトリにフォールバック

///|
fn detect_os_impl() -> OsKind {
  OsKind::Unknown
}

///|
fn home_dir_impl() -> String {
  ""
}

///|
fn config_dir_impl() -> String {
  "."
}

///|
fn data_dir_impl() -> String {
  "."
}

///|
fn cache_dir_impl() -> String {
  "."
}

///|
fn temp_dir_impl() -> String {
  "/tmp"
}
