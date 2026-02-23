///|
/// Key-Valueストア トレイト
/// 汎用的なキー・バリューストレージを抽象化
pub(open) trait KVStore {
  /// 値を取得
  get(Self, key~ : String) -> String? raise
  /// 値を設定
  set(Self, key~ : String, value~ : String) -> Unit raise
  /// 値を削除
  remove(Self, key~ : String) -> Unit raise
  /// キーが存在するか確認
  has(Self, key~ : String) -> Bool raise
  /// 全キーのリスト
  keys(Self) -> Array[String] raise
  /// 全データをクリア
  clear(Self) -> Unit raise
}

///|
/// JSON対応ストア トレイト
/// JSONデータの保存・取得を担当
pub(open) trait JsonStore {
  /// JSON値を取得
  get_json(Self, key~ : String) -> Json? raise
  /// JSON値を設定
  set_json(Self, key~ : String, value~ : Json) -> Unit raise
  /// 複数のJSON値を取得
  get_many(Self, keys~ : Array[String]) -> Array[(String, Json)] raise
  /// 複数のJSON値を設定
  set_many(Self, entries~ : Array[(String, Json)]) -> Unit raise
}

///|
/// ファイルストア トレイト
/// ファイルシステムへのアクセスを抽象化
pub(open) trait FileStore {
  /// ファイルを読み込み
  read_file(Self, path~ : String) -> Bytes raise
  /// ファイルを書き込み
  write_file(Self, path~ : String, data~ : Bytes) -> Unit raise
  /// ファイルが存在するか確認
  exists(Self, path~ : String) -> Bool raise
  /// ファイルを削除
  remove_file(Self, path~ : String) -> Unit raise
  /// ディレクトリを作成
  create_dir(Self, path~ : String) -> Unit raise
  /// ディレクトリ内のファイル一覧
  list_dir(Self, path~ : String) -> Array[String] raise
}
