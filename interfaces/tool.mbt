///|
/// ツール実行トレイト
/// 個々のツールの実行を担当する
pub(open) trait ToolExecutor {
  /// ツールを実行
  execute(
    Self,
    tool_name~ : String,
    arguments~ : Json,
    context~ : @types.ToolContext,
  ) -> @types.ToolResult raise
}

///|
/// ツールレジストリ トレイト
/// ツールの登録と取得を管理する
pub(open) trait ToolRegistry {
  /// ツールを登録
  register(Self, @types.ToolDefinition, &ToolExecutor) -> Unit
  /// ツール定義一覧を取得
  list_definitions(Self) -> Array[@types.ToolDefinition]
  /// ツール実行者を取得
  get_executor(Self, String) -> &ToolExecutor?
  /// ツールが存在するか確認
  has_tool(Self, String) -> Bool
}

///|
/// ツールエラー種別
pub(all) suberror ToolError {
  /// ツールが見つからない
  NotFound(String)
  /// 引数が不正
  InvalidArguments(String)
  /// 実行失敗
  ExecutionFailed(String)
  /// 権限不足
  PermissionDenied(String)
  /// タイムアウト
  Timeout
}
