///|
/// Native C FFI - 環境変数
/// Environment variable operations

// ============================================================
// CString版 (Pattern A)
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
) -> Int = "moonbit_setenv"

///|
/// 環境変数を削除
#borrow(name)
pub extern "C" fn c_unsetenv(name : CString) -> Int = "moonbit_unsetenv"

// ============================================================
// UTF-8 Bytes版 (Pattern B - 推奨)
// ============================================================

///|
/// setenv - UTF-8 Bytes版
#borrow(name, value)
pub extern "C" fn c_setenv_bytes(
  name : Bytes,
  value : Bytes,
  overwrite : Int,
) -> Int = "moonbit_setenv_bytes"

///|
/// unsetenv - UTF-8 Bytes版
#borrow(name)
pub extern "C" fn c_unsetenv_bytes(name : Bytes) -> Int = "moonbit_unsetenv_bytes"

// ============================================================
// errno
// ============================================================

///|
/// errno を取得
pub extern "C" fn c_get_errno() -> Int = "moonbit_get_errno"
