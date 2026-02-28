///|
/// Filesystem security tests
test "resolve_path rejects path traversal with dotdot" {
  let fs = NativeFileStore::new(base_dir=Some("/tmp/safe"))
  let result : Result[Array[String], _] = try? @interfaces.FileStore::list_dir(
    fs,
    path="../../etc",
  )
  assert_true(result is Err(_))
}

///|
test "resolve_path rejects absolute path traversal" {
  let fs = NativeFileStore::new(base_dir=Some("/tmp/safe"))
  let result : Result[Bytes, _] = try? @interfaces.FileStore::read_file(
    fs,
    path="../../../etc/passwd",
  )
  assert_true(result is Err(_))
}
