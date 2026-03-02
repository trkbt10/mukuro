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

///|
/// OS標準の一時ディレクトリを取得
/// Linux/macOS: $TMPDIR or /tmp
/// Windows: %TEMP% or %TMP% or C:\Windows\Temp
pub fn temp_dir() -> String {
  temp_dir_impl()
}

///|
/// アプリ名付きの一時ディレクトリを取得
/// テスト用に使用する場合は、テスト終了時にクリーンアップすること
pub fn temp_dir_for(app_name : String) -> String {
  temp_dir() + "/" + app_name
}

///|
/// 絶対パスを相対パスに変換（base_dir prefix を除去）
/// e.g. "/Users/.../mukuro/history/2026/03/02/file.jsonl" → "history/2026/03/02/file.jsonl"
pub fn to_relative_path(file_path : String, base_dir : String) -> String {
  // base_dir が "/" で終わらない場合は "/" を付加してプレフィックスチェック
  let prefix = if base_dir.has_suffix("/") {
    base_dir
  } else {
    "\{base_dir}/"
  }
  if file_path.has_prefix(prefix) {
    // prefix を除去して相対パスに
    let sb = StringBuilder::new()
    let chars = file_path.to_array()
    for i = prefix.length(); i < chars.length(); i = i + 1 {
      sb.write_char(chars[i])
    }
    sb.to_string()
  } else {
    // 既に相対パスまたは異なる base_dir の場合はそのまま
    file_path
  }
}

///|
/// 相対パスを絶対パスに変換（base_dir を prefix として結合）
/// e.g. "history/2026/03/02/file.jsonl" → "/Users/.../mukuro/history/2026/03/02/file.jsonl"
/// 既に絶対パス（"/" で始まる）の場合はそのまま返す（レガシーデータ互換）
pub fn to_absolute_path(file_path : String, base_dir : String) -> String {
  // 既に絶対パスの場合はそのまま
  if file_path.has_prefix("/") {
    return file_path
  }
  // base_dir が "/" で終わる場合はそのまま結合、そうでなければ "/" を追加
  if base_dir.has_suffix("/") {
    "\{base_dir}\{file_path}"
  } else {
    "\{base_dir}/\{file_path}"
  }
}
