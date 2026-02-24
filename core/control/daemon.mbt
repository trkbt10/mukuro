///|
/// Daemon管理
/// PIDファイル管理とデーモンモードサポート

///|
/// デーモンエラー
pub(all) suberror DaemonError {
  /// PIDファイルが既に存在（別プロセスが実行中）
  AlreadyRunning(Int)
  /// PIDファイルの読み取りエラー
  PidFileReadError(String)
  /// PIDファイルの書き込みエラー
  PidFileWriteError(String)
  /// プロセスが見つからない
  ProcessNotFound(Int)
  /// シグナル送信エラー
  SignalError(String)
  /// 初期化エラー
  InitError(String)
}

///|
/// PIDファイルパス（デフォルト）
pub let default_pid_path : String = ".mukuro/gateway.pid"

///|
/// IPCソケットパス（デフォルト）
pub let default_ipc_socket_path : String = ".mukuro/gateway.sock"

///|
/// 状態スナップショットパス（デフォルト）
pub let default_gateway_state_path : String = ".mukuro/gateway-state.json"

///|
/// PIDファイル管理
pub struct PidManager {
  /// PIDファイルのパス
  pid_path : String
  /// ファイルストア
  fs : &@interfaces.FileStore
}

///|
/// PidManagerを作成
pub fn PidManager::new(
  pid_path~ : String,
  fs~ : &@interfaces.FileStore,
) -> PidManager {
  { pid_path, fs }
}

///|
/// デフォルトパスでPidManagerを作成
pub fn PidManager::with_default_path(
  fs~ : &@interfaces.FileStore,
) -> PidManager {
  { pid_path: default_pid_path, fs }
}

///|
/// PIDファイルが存在するか確認
pub fn PidManager::exists(self : PidManager) -> Bool {
  self.fs.exists(path=self.pid_path) catch {
    _ => false
  }
}

///|
/// PIDファイルからPIDを読み取る
pub fn PidManager::read_pid(self : PidManager) -> Int raise DaemonError {
  let bytes = self.fs.read_file(path=self.pid_path) catch {
    e => raise DaemonError::PidFileReadError(e.to_string())
  }
  let content = bytes.to_unchecked_string().trim(chars=" \t\n\r")
  let json : Json = @json.parse(content) catch {
    _ => raise DaemonError::PidFileReadError("Invalid PID format: \{content}")
  }
  match json {
    Number(n, ..) => n.to_int()
    _ => raise DaemonError::PidFileReadError("Invalid PID format: \{content}")
  }
}

///|
/// PIDファイルを書き込む
pub fn PidManager::write_pid(
  self : PidManager,
  pid : Int,
) -> Unit raise DaemonError {
  let content = "\{pid}"
  self.fs.write_file(path=self.pid_path, data=content.to_bytes()) catch {
    e => raise DaemonError::PidFileWriteError(e.to_string())
  }
}

///|
/// PIDファイルを削除
pub fn PidManager::remove_pid(self : PidManager) -> Unit raise DaemonError {
  self.fs.remove_file(path=self.pid_path) catch {
    e => raise DaemonError::PidFileWriteError(e.to_string())
  }
}

///|
/// プロセス存在確認インターフェース
pub(open) trait ProcessChecker {
  /// プロセスが実行中か確認
  is_running(Self, pid : Int) -> Bool
  /// 現在のプロセスIDを取得
  current_pid(Self) -> Int
  /// プロセスにシグナルを送信（0: SIGTERM）
  send_signal(Self, pid : Int, signal : Int) -> Bool
}

///|
/// デーモン状態
pub(all) enum DaemonStatus {
  /// 実行中（PID付き）
  Running(Int)
  /// 停止中
  Stopped
  /// 状態不明（PIDファイル存在、プロセス不在 = stale）
  Stale(Int)
}

///|
/// デーモンマネージャ
pub struct DaemonManager {
  /// PIDマネージャ
  pid_manager : PidManager
  /// プロセスチェッカー
  process_checker : &ProcessChecker
}

///|
/// DaemonManagerを作成
pub fn DaemonManager::new(
  pid_manager~ : PidManager,
  process_checker~ : &ProcessChecker,
) -> DaemonManager {
  { pid_manager, process_checker }
}

///|
/// デーモン状態を取得
pub fn DaemonManager::status(self : DaemonManager) -> DaemonStatus {
  if !self.pid_manager.exists() {
    return DaemonStatus::Stopped
  }
  let pid = self.pid_manager.read_pid() catch {
    _ => return DaemonStatus::Stopped
  }
  if self.process_checker.is_running(pid) {
    DaemonStatus::Running(pid)
  } else {
    DaemonStatus::Stale(pid)
  }
}

///|
/// デーモン起動（PIDファイル作成、二重起動防止）
pub fn DaemonManager::acquire(self : DaemonManager) -> Unit raise DaemonError {
  // 既存のデーモン状態をチェック
  match self.status() {
    DaemonStatus::Running(pid) => raise DaemonError::AlreadyRunning(pid)
    DaemonStatus::Stale(_) =>
      // stale PIDファイルを削除
      self.pid_manager.remove_pid() catch {
        _ => ()
      }
    DaemonStatus::Stopped => ()
  }
  // 現在のPIDを書き込み
  let current_pid = self.process_checker.current_pid()
  self.pid_manager.write_pid(current_pid) catch {
    e => raise e
  }
}

///|
/// デーモン停止（PIDファイル削除）
pub fn DaemonManager::release(self : DaemonManager) -> Unit raise DaemonError {
  if self.pid_manager.exists() {
    self.pid_manager.remove_pid() catch {
      e => raise e
    }
  }
}

///|
/// リモートデーモンを停止（シグナル送信）
pub fn DaemonManager::stop_remote(
  self : DaemonManager,
) -> Unit raise DaemonError {
  match self.status() {
    DaemonStatus::Running(pid) =>
      // SIGTERMを送信
      if !self.process_checker.send_signal(pid, 15) {
        raise DaemonError::SignalError("Failed to send SIGTERM to pid \{pid}")
      }
    DaemonStatus::Stale(pid) => {
      // stale PIDファイルを削除
      self.pid_manager.remove_pid() catch {
        _ => ()
      }
      raise DaemonError::ProcessNotFound(pid)
    }
    DaemonStatus::Stopped => raise DaemonError::ProcessNotFound(0)
  }
}

///|
/// stale状態を回復（PIDファイル削除）
pub fn DaemonManager::recover_stale(self : DaemonManager) -> Bool {
  match self.status() {
    DaemonStatus::Stale(_) => {
      self.pid_manager.remove_pid() catch {
        _ => ()
      }
      true
    }
    _ => false
  }
}
