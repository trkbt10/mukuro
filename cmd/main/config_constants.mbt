///|
/// Config constants (all targets)
/// Source of truth: @interfaces.gateway_default_port, @interfaces.gateway_default_host

///|
/// デフォルト設定ファイルパスを取得
/// Native: ~/.mukuro/config.json
/// JS/WASM: .mukuro/config.json
pub fn default_runtime_config_path() -> String {
  @config.config_file()
}
