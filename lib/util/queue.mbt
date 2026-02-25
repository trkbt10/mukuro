///|
/// Queue Utilities
/// Simple queue operations for arrays

///|
/// Pop first element from array (FIFO)
pub fn pop_first[T](queue : Array[T]) -> T? {
  if queue.length() == 0 {
    None
  } else {
    let first = queue[0]
    let rest : Array[T] = []
    for i in 1..<queue.length() {
      rest.push(queue[i])
    }
    queue.clear()
    for item in rest {
      queue.push(item)
    }
    Some(first)
  }
}
