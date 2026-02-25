///|
/// 注意: このパッケージはJSON構文アクセスのみを担当する。
/// provider/channel などのドメイン意味や既定値ポリシーは扱わない。
///

///|
/// JSON文字列をルートオブジェクトにパースする（構文アクセス専用）
pub fn parse_root_object(raw : String) -> Result[Map[String, Json], String] {
  let json : Json = @json.parse(raw) catch {
    e => return Err("Invalid config JSON: \{e.to_string()}")
  }
  match json {
    Object(obj) => Ok(obj)
    _ => Err("Config must be a JSON object")
  }
}

///|
/// boolフィールドを取得する（未設定時はdefault_value）
pub fn bool_field_or_default(
  obj : Map[String, Json],
  key : String,
  default_value : Bool,
) -> Result[Bool, String] {
  match obj.get(key) {
    Some(True) => Ok(true)
    Some(False) => Ok(false)
    Some(_) => Err("Field '\{key}' must be a boolean")
    None => Ok(default_value)
  }
}

///|
/// stringフィールドを取得する（未設定時はdefault_value）
pub fn string_field_or_default(
  obj : Map[String, Json],
  key : String,
  default_value : String,
) -> Result[String, String] {
  match obj.get(key) {
    Some(String(value)) => Ok(value)
    Some(_) => Err("Field '\{key}' must be a string")
    None => Ok(default_value)
  }
}

///|
/// intフィールドを取得する（未設定時はdefault_value）
pub fn int_field_or_default(
  obj : Map[String, Json],
  key : String,
  default_value : Int,
) -> Result[Int, String] {
  match obj.get(key) {
    Some(Number(value, ..)) => Ok(value.to_int())
    Some(_) => Err("Field '\{key}' must be a number")
    None => Ok(default_value)
  }
}

///|
/// objectフィールドを取得する（未設定またはnullはNone）
pub fn optional_object_field(
  obj : Map[String, Json],
  key : String,
) -> Result[Map[String, Json]?, String] {
  match obj.get(key) {
    Some(Object(value)) => Ok(Some(value))
    Some(Null) => Ok(None)
    Some(_) => Err("Field '\{key}' must be an object")
    None => Ok(None)
  }
}

///|
/// arrayフィールドを取得する（未設定またはnullはNone）
pub fn optional_array_field(
  obj : Map[String, Json],
  key : String,
) -> Result[Array[Json]?, String] {
  match obj.get(key) {
    Some(Array(value)) => Ok(Some(value))
    Some(Null) => Ok(None)
    Some(_) => Err("Field '\{key}' must be an array")
    None => Ok(None)
  }
}

///|
/// 必須stringフィールドを取得する
pub fn required_string_field(
  obj : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match obj.get(key) {
    Some(String(value)) => Ok(value)
    Some(_) => Err("Field '\{key}' must be a string")
    None => Err("Field '\{key}' is required")
  }
}

///|
/// 必須intフィールドを取得する
pub fn required_int_field(
  obj : Map[String, Json],
  key : String,
) -> Result[Int, String] {
  match obj.get(key) {
    Some(Number(value, ..)) => Ok(value.to_int())
    Some(_) => Err("Field '\{key}' must be a number")
    None => Err("Field '\{key}' is required")
  }
}

///|
/// 必須int64フィールドを取得する
pub fn required_int64_field(
  obj : Map[String, Json],
  key : String,
) -> Result[Int64, String] {
  match obj.get(key) {
    Some(Number(value, ..)) => Ok(value.to_int64())
    Some(_) => Err("Field '\{key}' must be a number")
    None => Err("Field '\{key}' is required")
  }
}

///|
/// int64フィールドを取得する（未設定時はdefault_value）
pub fn int64_field_or_default(
  obj : Map[String, Json],
  key : String,
  default_value : Int64,
) -> Result[Int64, String] {
  match obj.get(key) {
    Some(Number(value, ..)) => Ok(value.to_int64())
    Some(_) => Err("Field '\{key}' must be a number")
    None => Ok(default_value)
  }
}

///|
/// doubleフィールドを取得する（未設定時はdefault_value）
pub fn double_field_or_default(
  obj : Map[String, Json],
  key : String,
  default_value : Double,
) -> Result[Double, String] {
  match obj.get(key) {
    Some(Number(value, ..)) => Ok(value)
    Some(_) => Err("Field '\{key}' must be a number")
    None => Ok(default_value)
  }
}

///|
/// オプションstringフィールドを取得する（未設定またはnullはNone）
pub fn optional_string_field(
  obj : Map[String, Json],
  key : String,
) -> Result[String?, String] {
  match obj.get(key) {
    Some(String(value)) => Ok(Some(value))
    Some(Null) => Ok(None)
    Some(_) => Err("Field '\{key}' must be a string")
    None => Ok(None)
  }
}

///|
/// オプションintフィールドを取得する（未設定またはnullはNone）
pub fn optional_int_field(
  obj : Map[String, Json],
  key : String,
) -> Result[Int?, String] {
  match obj.get(key) {
    Some(Number(value, ..)) => Ok(Some(value.to_int()))
    Some(Null) => Ok(None)
    Some(_) => Err("Field '\{key}' must be a number")
    None => Ok(None)
  }
}

///|
/// オプションint64フィールドを取得する（未設定またはnullはNone）
pub fn optional_int64_field(
  obj : Map[String, Json],
  key : String,
) -> Result[Int64?, String] {
  match obj.get(key) {
    Some(Number(value, ..)) => Ok(Some(value.to_int64()))
    Some(Null) => Ok(None)
    Some(_) => Err("Field '\{key}' must be a number")
    None => Ok(None)
  }
}

///|
/// オプションdoubleフィールドを取得する（未設定またはnullはNone）
pub fn optional_double_field(
  obj : Map[String, Json],
  key : String,
) -> Result[Double?, String] {
  match obj.get(key) {
    Some(Number(value, ..)) => Ok(Some(value))
    Some(Null) => Ok(None)
    Some(_) => Err("Field '\{key}' must be a number")
    None => Ok(None)
  }
}

///|
/// オプションboolフィールドを取得する（未設定またはnullはNone）
pub fn optional_bool_field(
  obj : Map[String, Json],
  key : String,
) -> Result[Bool?, String] {
  match obj.get(key) {
    Some(True) => Ok(Some(true))
    Some(False) => Ok(Some(false))
    Some(Null) => Ok(None)
    Some(_) => Err("Field '\{key}' must be a boolean")
    None => Ok(None)
  }
}

///|
/// string配列フィールドを取得する（未設定時は空配列）
pub fn string_array_field_or_default(
  obj : Map[String, Json],
  key : String,
) -> Result[Array[String], String] {
  match obj.get(key) {
    Some(Array(arr)) => {
      let result : Array[String] = []
      for item in arr {
        match item {
          String(s) => result.push(s)
          _ => return Err("Field '\{key}' must contain only strings")
        }
      }
      Ok(result)
    }
    Some(Null) => Ok([])
    Some(_) => Err("Field '\{key}' must be an array")
    None => Ok([])
  }
}
