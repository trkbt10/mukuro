///|
/// JSON Parameter Extraction Utilities

///|
pub fn get_string(params : Json?, key : String) -> String? {
  match params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
pub fn get_number(params : Json?, key : String) -> Double? {
  match params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
    _ => None
  }
}

///|
pub fn get_int(params : Json?, key : String) -> Int? {
  match get_number(params, key) {
    Some(n) => Some(n.to_int())
    None => None
  }
}

///|
pub fn get_bool(params : Json?, key : String) -> Bool? {
  match params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(True) => Some(true)
        Some(False) => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
pub fn get_string_array(params : Json?, key : String) -> Array[String]? {
  match params {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Array(arr)) => {
          let result : Array[String] = []
          for item in arr {
            match item {
              String(s) => result.push(s)
              _ => ()
            }
          }
          Some(result)
        }
        _ => None
      }
    _ => None
  }
}
