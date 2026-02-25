///|
/// ID Generator
/// Generates unique sequential identifiers with a prefix

///|
pub struct IdGenerator {
  prefix : String
  mut counter : Int
}

///|
pub fn IdGenerator::new(prefix : String) -> IdGenerator {
  { prefix, counter: 1 }
}

///|
pub fn IdGenerator::next(self : IdGenerator) -> String {
  let id = "\{self.prefix}_\{self.counter}"
  self.counter = self.counter + 1
  id
}

///|
pub fn IdGenerator::reset(self : IdGenerator) -> Unit {
  self.counter = 1
}

///|
pub fn IdGenerator::current(self : IdGenerator) -> Int {
  self.counter
}
