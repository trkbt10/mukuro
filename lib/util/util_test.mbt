///|
test "pop_first empty array" {
  let arr : Array[Int] = []
  inspect!(pop_first(arr), content="None")
}

///|
test "pop_first single element" {
  let arr = [42]
  inspect!(pop_first(arr), content="Some(42)")
  inspect!(arr.length(), content="0")
}

///|
test "pop_first multiple elements" {
  let arr = [1, 2, 3]
  inspect!(pop_first(arr), content="Some(1)")
  inspect!(arr.length(), content="2")
  inspect!(arr[0], content="2")
  inspect!(arr[1], content="3")
}

///|
test "pop_first preserves order" {
  let arr = ["a", "b", "c"]
  inspect!(pop_first(arr), content="Some(\"a\")")
  inspect!(pop_first(arr), content="Some(\"b\")")
  inspect!(pop_first(arr), content="Some(\"c\")")
  inspect!(pop_first(arr), content="None")
}
