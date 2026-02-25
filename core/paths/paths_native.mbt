///|
/// Native専用: ホームディレクトリ取得

///|
/// ホームディレクトリを取得
fn home_dir_impl() -> String {
  let buffer_len = 1024
  let buffer = Bytes::new(buffer_len)
  let read_len = c_get_home_dir(buffer, buffer_len)
  if read_len <= 0 {
    return ""
  }
  @utf8.decode(buffer[:read_len]) catch {
    _ => ""
  }
}

///|
/// HOME環境変数を取得してバッファに書き込む
#borrow(buffer)
extern "C" fn c_get_home_dir(buffer : Bytes, buffer_len : Int) -> Int = "moonbit_get_home_dir"
