///|
/// Native C FFI - 時刻関連
/// Time-related POSIX functions

///|
/// 現在時刻を取得（Unix epoch 秒）
pub extern "C" fn c_time() -> Int64 = "moonbit_time_now"

///|
/// Unix epoch秒から年月日を取得（gmtime_r ラッパー）
/// out_buf: 12バイト出力バッファ（year:4, month:4, day:4、リトルエンディアン）
/// returns: 0 on success, -1 on error
#borrow(out_buf)
pub extern "C" fn c_gmtime(epoch_secs : Int64, out_buf : Bytes) -> Int = "moonbit_gmtime"
