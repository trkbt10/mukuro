///|
/// Config constants (JS/WASM targets)

///|
/// デフォルト設定ファイルパスを取得
pub fn default_runtime_config_path() -> String {
  @config.config_file()
}

///|
/// 設定ファイルが存在するか確認（非native: 常にtrueを返す）
pub fn runtime_config_exists(_path : String) -> Bool {
  true
}

///|
/// 設定ファイル未検出時のエラーメッセージ
pub fn config_not_found_message(path : String) -> String {
  "Configuration file not found: \{path}\n\nRun 'mukuro onboard --provider <provider> --api-key <key>' to initialize configuration."
}
