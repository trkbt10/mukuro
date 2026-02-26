///|
/// mukuro アプリケーション固有のパス解決モジュール
/// core/dirs を使ってOS標準ディレクトリを取得し、mukuro固有のパスを構築

///|
/// パスモード
pub(all) enum PathMode {
  /// OS標準パス（デフォルト）
  Standard
  /// カレントディレクトリの.mukuro（プロジェクトローカル）
  Local
  /// 任意パス指定
  Custom(String)
}

///|
/// mukuro ディレクトリ名（Local mode用）
let mukuro_dir_name : String = ".mukuro"

///|
/// アプリ名（Standard mode用）
pub let app_name : String = "mukuro"

///|
/// グローバルなパスモード設定
let path_mode : Ref[PathMode] = Ref::new(PathMode::Standard)

///|
/// パスモードを設定
pub fn set_path_mode(mode : PathMode) -> Unit {
  path_mode.val = mode
}

///|
/// 現在のパスモードを取得
pub fn get_path_mode() -> PathMode {
  path_mode.val
}

///|
/// 現在のモードに応じた設定ディレクトリを取得
pub fn config_dir() -> String {
  match path_mode.val {
    Standard => @dirs.config_dir_for(app_name)
    Local => mukuro_dir_name
    Custom(base) => base
  }
}

///|
/// 現在のモードに応じたデータディレクトリを取得
pub fn data_dir() -> String {
  match path_mode.val {
    Standard => @dirs.data_dir_for(app_name)
    Local => mukuro_dir_name
    Custom(base) => base
  }
}

///|
/// 現在のモードに応じたキャッシュ/ランタイムディレクトリを取得
pub fn cache_dir() -> String {
  match path_mode.val {
    Standard => @dirs.cache_dir_for(app_name)
    Local => mukuro_dir_name
    Custom(base) => base
  }
}

///|
/// ローカル(.mukuro)ディレクトリのパスを取得
pub fn local_dir() -> String {
  mukuro_dir_name
}

///|
/// 設定ファイルのパスを取得
pub fn config_file() -> String {
  config_dir() + "/config.json"
}

///|
/// PIDファイルのパスを取得
pub fn pid_file() -> String {
  cache_dir() + "/gateway.pid"
}

///|
/// IPCソケットのパスを取得
pub fn socket_file() -> String {
  cache_dir() + "/gateway.sock"
}

///|
/// Gateway状態スナップショットのパスを取得
pub fn state_file() -> String {
  data_dir() + "/gateway-state.json"
}

///|
/// Gateway認証トークンのパスを取得
pub fn token_file() -> String {
  cache_dir() + "/gateway.token"
}

///|
/// Gateway認証ログのパスを取得
pub fn auth_log_file() -> String {
  cache_dir() + "/gateway-auth.log"
}

///|
/// ワークスペースディレクトリのパスを取得
pub fn workspace_dir() -> String {
  data_dir() + "/workspace"
}
