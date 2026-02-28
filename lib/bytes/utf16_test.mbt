///|
test "parse_utf16le_lines - empty buffer" {
  let buffer = Bytes::new(0)
  let result = @bytes.parse_utf16le_lines(buffer, 0)
  inspect!(result.length(), content="0")
}

///|
test "parse_utf16le_lines - single entry" {
  // "abc" in UTF-16LE: 0x61 0x00, 0x62 0x00, 0x63 0x00
  let buffer = Bytes::from_iter(
    [b'\x61', b'\x00', b'\x62', b'\x00', b'\x63', b'\x00'].iter(),
  )
  let result = @bytes.parse_utf16le_lines(buffer, 6)
  inspect!(result.length(), content="1")
  inspect!(result[0], content="abc")
}

///|
test "parse_utf16le_lines - multiple entries with newlines" {
  // "a\nb\nc" in UTF-16LE
  let buffer = Bytes::from_iter(
    [
      b'\x61', b'\x00', // 'a'
      b'\x0A', b'\x00', // '\n'
      b'\x62', b'\x00', // 'b'
      b'\x0A', b'\x00', // '\n'
      b'\x63', b'\x00', // 'c'
    ]
    .iter(),
  )
  let result = @bytes.parse_utf16le_lines(buffer, 10)
  inspect!(result.length(), content="3")
  inspect!(result[0], content="a")
  inspect!(result[1], content="b")
  inspect!(result[2], content="c")
}

///|
test "parse_utf16le_lines - trailing newline" {
  // "file1\nfile2\n" in UTF-16LE
  let buffer = Bytes::from_iter(
    [
      b'\x66', b'\x00', // 'f'
      b'\x31', b'\x00', // '1'
      b'\x0A', b'\x00', // '\n'
      b'\x66', b'\x00', // 'f'
      b'\x32', b'\x00', // '2'
      b'\x0A', b'\x00', // '\n'
    ]
    .iter(),
  )
  let result = @bytes.parse_utf16le_lines(buffer, 12)
  inspect!(result.length(), content="2")
  inspect!(result[0], content="f1")
  inspect!(result[1], content="f2")
}

///|
test "parse_utf16le_lines - empty lines skipped" {
  // "a\n\nb" in UTF-16LE — 空行はスキップされる
  let buffer = Bytes::from_iter(
    [
      b'\x61', b'\x00', // 'a'
      b'\x0A', b'\x00', // '\n'
      b'\x0A', b'\x00', // '\n' (empty line)
      b'\x62', b'\x00', // 'b'
    ]
    .iter(),
  )
  let result = @bytes.parse_utf16le_lines(buffer, 8)
  inspect!(result.length(), content="2")
  inspect!(result[0], content="a")
  inspect!(result[1], content="b")
}

///|
test "parse_utf16le_lines - odd byte count (truncated)" {
  // 奇数バイト: 最後の不完全なペアは無視
  let buffer = Bytes::from_iter(
    [b'\x61', b'\x00', b'\x62'].iter(),
  )
  let result = @bytes.parse_utf16le_lines(buffer, 3)
  inspect!(result.length(), content="1")
  inspect!(result[0], content="a")
}

///|
test "parse_utf16le_lines - only newlines" {
  // "\n\n" in UTF-16LE — 空行のみ
  let buffer = Bytes::from_iter(
    [b'\x0A', b'\x00', b'\x0A', b'\x00'].iter(),
  )
  let result = @bytes.parse_utf16le_lines(buffer, 4)
  inspect!(result.length(), content="0")
}

///|
test "parse_utf16le_lines - non-ASCII (Japanese)" {
  // "あ" = U+3042, UTF-16LE: 0x42 0x30
  let buffer = Bytes::from_iter(
    [b'\x42', b'\x30'].iter(),
  )
  let result = @bytes.parse_utf16le_lines(buffer, 2)
  inspect!(result.length(), content="1")
  inspect!(result[0], content="あ")
}
