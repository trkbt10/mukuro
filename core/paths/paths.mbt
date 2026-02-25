///|
/// パス解決モジュール (Source of Truth)
/// 全てのパス定数はここから導出される

///|
/// mukuro ディレクトリ名
let mukuro_dir_name : String = ".mukuro"

///|
/// ホームディレクトリを取得（プラットフォーム依存）
/// Native: HOME環境変数から取得
/// JS/WASM: 空文字列を返す
pub fn home_dir() -> String {
  home_dir_impl()
}

///|
/// mukuro 設定ディレクトリのパスを取得
/// ホームディレクトリが取得できれば ~/.mukuro
/// 取得できなければ .mukuro (カレントディレクトリ相対)
pub fn config_dir() -> String {
  let home = home_dir()
  if home.is_empty() {
    mukuro_dir_name
  } else {
    home + "/" + mukuro_dir_name
  }
}

///|
/// 設定ファイルのパスを取得
pub fn config_file() -> String {
  config_dir() + "/config.json"
}

///|
/// PIDファイルのパスを取得
pub fn pid_file() -> String {
  config_dir() + "/gateway.pid"
}

///|
/// IPCソケットのパスを取得
pub fn socket_file() -> String {
  config_dir() + "/gateway.sock"
}

///|
/// Gateway状態スナップショットのパスを取得
pub fn state_file() -> String {
  config_dir() + "/gateway-state.json"
}

///|
/// Gateway認証トークンのパスを取得
pub fn token_file() -> String {
  config_dir() + "/gateway.token"
}

///|
/// Gateway認証ログのパスを取得
pub fn auth_log_file() -> String {
  config_dir() + "/gateway-auth.log"
}

///|
/// ワークスペースディレクトリのパスを取得
pub fn workspace_dir() -> String {
  config_dir() + "/workspace"
}
