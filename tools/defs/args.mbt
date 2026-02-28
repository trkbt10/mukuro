///|
/// JSONから文字列引数を取得
pub fn get_string_arg(args : Json, key : String) -> String? {
  match args {
    Object(obj) =>
      match obj.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// JSONから必須文字列引数を取得
pub fn require_string_arg(
  args : Json,
  key : String,
) -> String raise ToolExecutionError {
  match get_string_arg(args, key) {
    Some(s) => s
    None =>
      raise ToolExecutionError::InvalidArguments("Missing argument: \{key}")
  }
}

///|
/// JSONから整数引数を取得
pub fn get_int_arg(args : Json, key : String) -> Int? {
  match args {
    Object(obj) =>
      match obj.get(key) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

///|
/// JSONからブール引数を取得
pub fn get_bool_arg(args : Json, key : String) -> Bool? {
  match args {
    Object(obj) =>
      match obj.get(key) {
        Some(True) => Some(true)
        Some(False) => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
/// JSONから配列引数を取得
pub fn get_array_arg(args : Json, key : String) -> Array[Json]? {
  match args {
    Object(obj) =>
      match obj.get(key) {
        Some(Array(arr)) => Some(arr)
        _ => None
      }
    _ => None
  }
}
