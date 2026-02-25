///|
/// State Management Utilities

///|
/// Connection state
pub struct ConnectionState {
  mut connected : Bool
  mut last_error : String?
  mut connect_time : Int64?
}

///|
pub fn ConnectionState::new() -> ConnectionState {
  { connected: false, last_error: None, connect_time: None }
}

///|
pub fn ConnectionState::connect(self : ConnectionState, timestamp~ : Int64 = 0L) -> Unit {
  self.connected = true
  self.last_error = None
  self.connect_time = Some(timestamp)
}

///|
pub fn ConnectionState::disconnect(self : ConnectionState) -> Unit {
  self.connected = false
  self.connect_time = None
}

///|
pub fn ConnectionState::set_error(self : ConnectionState, error : String) -> Unit {
  self.connected = false
  self.last_error = Some(error)
}

///|
pub fn ConnectionState::is_connected(self : ConnectionState) -> Bool {
  self.connected
}

///|
/// Timestamp generator (for testing/simulation)
pub struct TimestampGenerator {
  mut value : Int64
}

///|
pub fn TimestampGenerator::new(start~ : Int64 = 1000000000000L) -> TimestampGenerator {
  { value: start }
}

///|
pub fn TimestampGenerator::next(self : TimestampGenerator) -> Int64 {
  let ts = self.value
  self.value = self.value + 1L
  ts
}

///|
pub fn TimestampGenerator::set(self : TimestampGenerator, value : Int64) -> Unit {
  self.value = value
}

///|
pub fn TimestampGenerator::current(self : TimestampGenerator) -> Int64 {
  self.value
}
