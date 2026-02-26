///|
/// OS標準ディレクトリ解決モジュール
/// XDG Base Directory / macOS / Windows 規約に基づく

///|
/// OS種別
pub(all) enum OsKind {
  Linux
  MacOS
  Windows
  Unknown
}

///|
/// OS種別を取得（プラットフォーム依存）
pub fn detect_os() -> OsKind {
  detect_os_impl()
}

///|
/// ホームディレクトリを取得
/// Native: HOME環境変数から取得
/// JS/WASM: 空文字列を返す
pub fn home_dir() -> String {
  home_dir_impl()
}

///|
/// OS標準の設定ディレクトリを取得
/// Linux: $XDG_CONFIG_HOME or ~/.config
/// macOS: ~/Library/Application Support
/// Windows: %APPDATA%
pub fn config_dir() -> String {
  config_dir_impl()
}

///|
/// OS標準のデータディレクトリを取得
/// Linux: $XDG_DATA_HOME or ~/.local/share
/// macOS: ~/Library/Application Support
/// Windows: %APPDATA%
pub fn data_dir() -> String {
  data_dir_impl()
}

///|
/// OS標準のキャッシュ/ランタイムディレクトリを取得
/// Linux: $XDG_RUNTIME_DIR or $XDG_CACHE_HOME or ~/.cache
/// macOS: ~/Library/Caches
/// Windows: %LOCALAPPDATA%
pub fn cache_dir() -> String {
  cache_dir_impl()
}

///|
/// アプリ名付きの設定ディレクトリを取得
pub fn config_dir_for(app_name : String) -> String {
  config_dir() + "/" + app_name
}

///|
/// アプリ名付きのデータディレクトリを取得
pub fn data_dir_for(app_name : String) -> String {
  data_dir() + "/" + app_name
}

///|
/// アプリ名付きのキャッシュディレクトリを取得
pub fn cache_dir_for(app_name : String) -> String {
  cache_dir() + "/" + app_name
}
