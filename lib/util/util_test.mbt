///|
test "pop_first empty array" {
  let arr : Array[Int] = []
  inspect(pop_first(arr), content="None")
}

///|
test "pop_first single element" {
  let arr = [42]
  inspect(pop_first(arr), content="Some(42)")
  inspect(arr.length(), content="0")
}

///|
test "pop_first multiple elements" {
  let arr = [1, 2, 3]
  inspect(pop_first(arr), content="Some(1)")
  inspect(arr.length(), content="2")
  inspect(arr[0], content="2")
  inspect(arr[1], content="3")
}

///|
test "pop_first preserves order" {
  let arr = ["a", "b", "c"]
  inspect(pop_first(arr), content="Some(\"a\")")
  inspect(pop_first(arr), content="Some(\"b\")")
  inspect(pop_first(arr), content="Some(\"c\")")
  inspect(pop_first(arr), content="None")
}

///|
test "IdGenerator::new default start" {
  let gen = IdGenerator::new("msg_")
  inspect(gen.current(), content="1")
}

///|
test "IdGenerator::new custom start" {
  let gen = IdGenerator::new("id_", start=100L)
  inspect(gen.current(), content="100")
}

///|
test "IdGenerator::next generates sequential ids" {
  let gen = IdGenerator::new("task_")
  inspect(gen.next(), content="task_1")
  inspect(gen.next(), content="task_2")
  inspect(gen.next(), content="task_3")
}

///|
test "IdGenerator::current does not increment" {
  let gen = IdGenerator::new("x_", start=10L)
  inspect(gen.current(), content="10")
  inspect(gen.current(), content="10")
  let _ = gen.next()
  inspect(gen.current(), content="11")
}

///|
test "IdGenerator::reset" {
  let gen = IdGenerator::new("ev_")
  let _ = gen.next()
  let _ = gen.next()
  gen.reset(1L)
  inspect(gen.next(), content="ev_1")
}

// =============================================================================
// Shell Escape Tests
// =============================================================================

///|
test "escape_shell_single_quote no quotes" {
  inspect(escape_shell_single_quote("hello world"), content="hello world")
}

///|
test "escape_shell_single_quote with quotes" {
  inspect(escape_shell_single_quote("it's a test"), content="it'\\''s a test")
}

///|
test "escape_shell_single_quote empty string" {
  inspect(escape_shell_single_quote(""), content="")
}
