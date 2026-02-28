///|
test "copy_slice - exact copy" {
  let original = @utf8.encode("hello")
  let copied = @bytes.copy_slice(original[:])
  inspect!(copied.length(), content="5")
  for i in 0..<5 {
    assert_eq!(copied[i], original[i])
  }
}

///|
test "copy_slice - empty" {
  let original = Bytes::new(0)
  let copied = @bytes.copy_slice(original[:])
  inspect!(copied.length(), content="0")
}

///|
test "copy_slice - partial slice" {
  let original = @utf8.encode("hello world")
  let copied = @bytes.copy_slice(original[:5])
  inspect!(copied.length(), content="5")
  let expected = @utf8.encode("hello")
  for i in 0..<5 {
    assert_eq!(copied[i], expected[i])
  }
}

///|
test "copy_slice - independence from original" {
  let original = Bytes::new(4)
  let copied = @bytes.copy_slice(original[:])
  // コピー後の original への変更は copied に影響しない
  // (Bytes は immutable なので参照の独立性を確認)
  inspect!(copied.length(), content="4")
  assert_eq!(copied[0], b'\x00')
}
