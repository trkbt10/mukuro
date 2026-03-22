///|
/// Cron ジョブ永続化 — Native ファイル I/O

///|
#borrow(path, mode)
extern "C" fn sched_fopen(path : Bytes, mode : Bytes) -> Int64 = "moonbit_fopen_bytes"

///|
#borrow(data)
extern "C" fn sched_fwrite(
  data : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fwrite_handle"

///|
#borrow(buffer)
extern "C" fn sched_fread(
  buffer : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fread_handle"

///|
extern "C" fn sched_fclose(handle : Int64) -> Int = "moonbit_fclose_handle"

///|
/// TaskScheduler をファイルに保存
pub fn save_scheduler_to_file(scheduler : TaskScheduler, path : String) -> Bool {
  let json = scheduler_to_json(scheduler)
  let content = json.stringify()
  let data = @moonbit_encoding_utf8.encode(content.view())
  let path_bytes = @bytes.to_utf8_cstring(path)
  let mode_bytes = @bytes.to_utf8_cstring("wb")
  let handle = sched_fopen(path_bytes, mode_bytes)
  if handle == 0L {
    return false
  }
  let written = sched_fwrite(data, 1, data.length(), handle)
  let _ = sched_fclose(handle)
  written == data.length()
}

///|
/// ファイルから TaskScheduler を読み込み
pub fn load_scheduler_from_file(path : String) -> TaskScheduler {
  let path_bytes = @bytes.to_utf8_cstring(path)
  let mode_bytes = @bytes.to_utf8_cstring("rb")
  let handle = sched_fopen(path_bytes, mode_bytes)
  if handle == 0L {
    return TaskScheduler::new()
  }
  let buffer_size = 65536
  let buffer = Bytes::new(buffer_size)
  let bytes_read = sched_fread(buffer, 1, buffer_size, handle)
  let _ = sched_fclose(handle)
  if bytes_read <= 0 {
    return TaskScheduler::new()
  }
  let content = @moonbit_encoding_utf8.decode(buffer[:bytes_read]) catch {
    _ => return TaskScheduler::new()
  }
  let json : Json = @json.parse(content) catch {
    _ => return TaskScheduler::new()
  }
  scheduler_from_json(json)
}
