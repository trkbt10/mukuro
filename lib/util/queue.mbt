///|
/// Queue and Utility Functions
/// Simple queue operations and common utilities

///|
/// Pop first element from array (FIFO)
pub fn[T] pop_first(queue : Array[T]) -> T? {
  if queue.length() == 0 {
    None
  } else {
    Some(queue.remove(0))
  }
}

///|
/// Sequential ID Generator
/// Used by plugins for generating unique message/event IDs
pub struct IdGenerator {
  prefix : String
  mut counter : Int64
}

///|
/// Create a new ID generator with given prefix and starting value
pub fn IdGenerator::new(prefix : String, start? : Int64 = 1L) -> IdGenerator {
  { prefix, counter: start }
}

///|
/// Generate the next ID
pub fn IdGenerator::next(self : IdGenerator) -> String {
  let id = "\{self.prefix}\{self.counter}"
  self.counter = self.counter + 1L
  id
}

///|
/// Get current counter value without incrementing
pub fn IdGenerator::current(self : IdGenerator) -> Int64 {
  self.counter
}

///|
/// Reset counter to a specific value
pub fn IdGenerator::reset(self : IdGenerator, value : Int64) -> Unit {
  self.counter = value
}
