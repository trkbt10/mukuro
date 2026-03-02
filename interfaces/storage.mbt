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
