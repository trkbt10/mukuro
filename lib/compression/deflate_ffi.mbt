///|
/// Deflate FFI Declarations
/// Native zlib bindings for compression

///|
/// Compress data using deflate and return compressed size
/// Returns -1 on error
#borrow(src_buf)
extern "C" fn c_deflate_size(src_buf : Bytes, src_len : Int64) -> Int64 = "moonbit_deflate_size"

///|
/// Get upper bound of compressed size for given input size
extern "C" fn c_deflate_bound(src_len : Int64) -> Int64 = "moonbit_deflate_bound"

///|
/// Compress data using deflate
/// Returns compressed size, or -1 on error
#borrow(dest_buf, src_buf)
extern "C" fn c_deflate_compress(
  dest_buf : Bytes,
  dest_len : Int64,
  src_buf : Bytes,
  src_len : Int64,
) -> Int64 = "moonbit_deflate_compress"
