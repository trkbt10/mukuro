///|
/// Config constants (all targets)

///|
/// デフォルト設定ファイルパスを取得
/// Native: ~/.mukuro/config.json
/// JS/WASM: .mukuro/config.json
pub fn default_runtime_config_path() -> String {
  @config.config_file()
}
