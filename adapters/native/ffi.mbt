///|
/// Native C FFI 宣言
/// POSIX/libc ベースの低レベルインターフェース

// ============================================================
// 時刻関連
// ============================================================

///|
/// 現在時刻を取得（Unix epoch 秒）
pub extern "C" fn c_time() -> Int64 = "time"

// ============================================================
// 標準入出力
// ============================================================

///|
/// C FILE ポインタ
#external
pub type CFile

///|
/// 標準出力に文字列を出力
#borrow(s)
pub extern "C" fn c_puts(s : CString) -> Int = "puts"

///|
/// 標準エラーに文字列を出力
#borrow(s)
pub extern "C" fn c_fputs(s : CString, stream : CFile) -> Int = "fputs"

///|
/// stderr を取得（ヘルパー関数が必要）
pub extern "C" fn c_get_stderr() -> CFile = "moonbit_get_stderr"

// ============================================================
// ファイルシステム
// ============================================================

///|
/// ファイルを開く
#borrow(path, mode)
pub extern "C" fn c_fopen(path : CString, mode : CString) -> CFile? = "fopen"

///|
/// ファイルを閉じる
pub extern "C" fn c_fclose(file : CFile) -> Int = "fclose"

///|
/// ファイルから読み込み
pub extern "C" fn c_fread(
  ptr : Bytes,
  size : Int,
  nmemb : Int,
  stream : CFile,
) -> Int = "fread"

///|
/// ファイルに書き込み
pub extern "C" fn c_fwrite(
  ptr : Bytes,
  size : Int,
  nmemb : Int,
  stream : CFile,
) -> Int = "fwrite"

///|
/// ファイルの存在確認
#borrow(path)
pub extern "C" fn c_access(path : CString, mode : Int) -> Int = "access"

///|
/// ファイルを削除
#borrow(path)
pub extern "C" fn c_remove(path : CString) -> Int = "remove"

///|
/// ディレクトリを作成
#borrow(path)
pub extern "C" fn c_mkdir(path : CString, mode : Int) -> Int = "mkdir"

// ============================================================
// プロセス実行
// ============================================================

///|
/// コマンドを実行（popen）
#borrow(command, mode)
pub extern "C" fn c_popen(command : CString, mode : CString) -> CFile? = "popen"

///|
/// popen を閉じる
pub extern "C" fn c_pclose(stream : CFile) -> Int = "pclose"

///|
/// system コマンド実行
#borrow(command)
pub extern "C" fn c_system(command : CString) -> Int = "system"

// ============================================================
// 環境変数
// ============================================================

///|
/// 環境変数を取得
#borrow(name)
pub extern "C" fn c_getenv(name : CString) -> CString? = "getenv"

///|
/// 環境変数を設定
#borrow(name, value)
pub extern "C" fn c_setenv(
  name : CString,
  value : CString,
  overwrite : Int,
) -> Int = "setenv"

///|
/// 環境変数を削除
#borrow(name)
pub extern "C" fn c_unsetenv(name : CString) -> Int = "unsetenv"

// ============================================================
// 文字列変換ヘルパー
// ============================================================

///|
/// C文字列型（null終端）
#external
pub type CString

///|
/// MoonBit String から CString への変換
pub fn string_to_cstring(s : String) -> CString = "%identity"

///|
/// CString から MoonBit String への変換
pub fn cstring_to_string(cs : CString) -> String = "%identity"

// ============================================================
// 定数
// ============================================================

///|
/// F_OK (ファイル存在確認用)
pub let f_ok : Int = 0

///|
/// R_OK (読み取り権限確認用)
pub let r_ok : Int = 4

///|
/// W_OK (書き込み権限確認用)
pub let w_ok : Int = 2

///|
/// X_OK (実行権限確認用)
pub let x_ok : Int = 1
