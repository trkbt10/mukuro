///|
/// Config constants (native target)

///|
/// デフォルト設定ファイルパスを取得
/// Standard path のみを返す（フォールバックなし）
pub fn default_runtime_config_path() -> String {
  @core_config.config_file_for(@core_config.PathMode::Standard)
}

///|
/// 設定ファイルが存在するか確認
pub fn runtime_config_exists(path : String) -> Bool {
  @native.c_file_exists_bytes(@native.string_to_utf8_cstring(path)) == 1
}

///|
/// 設定ファイル未検出時のエラーメッセージ
pub fn config_not_found_message(path : String) -> String {
  "Configuration file not found: \{path}\n\nRun 'mukuro onboard' to see available providers and initialize configuration."
}
