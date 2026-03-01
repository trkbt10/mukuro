///|
/// Native C FFI - 標準入出力
/// Standard I/O functions

///|
/// stdinから1行読み取る
/// returns: 読み取ったバイト数（0=EOF、-1=エラー）
#borrow(buffer)
pub extern "C" fn c_read_stdin_line(buffer : Bytes, buffer_len : Int) -> Int = "moonbit_read_stdin_line"

///|
/// stdoutに書き込む（改行なし）
/// returns: 書き込んだバイト数、エラー時-1
#borrow(data)
pub extern "C" fn c_write_stdout(data : Bytes, len : Int) -> Int = "moonbit_write_stdout"

///|
/// stderrに書き込む
/// returns: 書き込んだバイト数、エラー時-1
#borrow(data)
pub extern "C" fn c_write_stderr(data : Bytes, len : Int) -> Int = "moonbit_write_stderr"

///|
/// stdout をフラッシュ
pub extern "C" fn c_fflush_stdout() -> Int = "moonbit_fflush_stdout"
