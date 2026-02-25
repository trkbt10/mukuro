///|
/// Tool Plugin - Utility Tools
/// Provides common utility functions: calculator, datetime, random, hash, etc.

///|
/// Calculator result
pub(all) struct CalcResult {
  /// Expression evaluated
  expression : String
  /// Result value
  result : Double
  /// Whether evaluation succeeded
  success : Bool
  /// Error message if failed
  error : String?
}

///|
/// Tool plugin
pub struct UtilityToolPlugin {
  /// Name of the plugin
  name : String
  /// Random seed (for reproducible testing)
  mut random_seed : Int64
}

///|
/// Create new utility tool plugin
pub fn UtilityToolPlugin::new(name~ : String) -> UtilityToolPlugin {
  { name, random_seed: 12345L }
}

///|
/// Set random seed (for testing)
pub fn UtilityToolPlugin::set_seed(self : UtilityToolPlugin, seed : Int64) -> Unit {
  self.random_seed = seed
}

///|
/// Simple pseudo-random number generator (LCG)
fn UtilityToolPlugin::next_random(self : UtilityToolPlugin) -> Int64 {
  // Linear Congruential Generator
  self.random_seed = (self.random_seed * 1103515245L + 12345L) % 2147483648L
  self.random_seed
}

///|
/// Generate random integer in range [min, max]
pub fn UtilityToolPlugin::random_int(
  self : UtilityToolPlugin,
  min : Int,
  max : Int,
) -> Int {
  if min >= max {
    min
  } else {
    let range = (max - min + 1).to_int64()
    let r = self.next_random() % range
    min + r.to_int()
  }
}

///|
/// Generate random float in range [0, 1)
pub fn UtilityToolPlugin::random_float(self : UtilityToolPlugin) -> Double {
  self.next_random().to_double() / 2147483648.0
}

///|
/// Generate UUID v4 (pseudo-random)
pub fn UtilityToolPlugin::uuid_v4(self : UtilityToolPlugin) -> String {
  let hex_chars = "0123456789abcdef"
  let mut result = ""
  for i = 0; i < 36; i = i + 1 {
    if i == 8 || i == 13 || i == 18 || i == 23 {
      result = result + "-"
    } else if i == 14 {
      result = result + "4" // Version 4
    } else if i == 19 {
      // Variant bits (8, 9, a, or b)
      let r = self.random_int(8, 11)
      result = result + hex_chars.substring(start=r, end=r + 1)
    } else {
      let r = self.random_int(0, 15)
      result = result + hex_chars.substring(start=r, end=r + 1)
    }
  }
  result
}

///|
/// Simple expression calculator
/// Supports: +, -, *, /, ^, parentheses
pub fn UtilityToolPlugin::calculate(
  _self : UtilityToolPlugin,
  expression : String,
) -> CalcResult {
  // Tokenize and parse
  let result = parse_and_evaluate(expression)
  match result {
    Ok(value) => { expression, result: value, success: true, error: None }
    Err(msg) => { expression, result: 0.0, success: false, error: Some(msg) }
  }
}

///|
/// Simple expression evaluator using recursive descent
/// Supports: +, -, *, /, parentheses
fn parse_and_evaluate(expression : String) -> Result[Double, String] {
  let chars = expression.to_array()
  let state : EvalState = { chars, pos: 0 }
  match state.parse_expr() {
    Ok(val) => Ok(val)
    Err(e) => Err(e)
  }
}

///|
priv struct EvalState {
  chars : Array[Char]
  mut pos : Int
}

///|
fn EvalState::skip_whitespace(self : EvalState) -> Unit {
  while self.pos < self.chars.length() {
    let c = self.chars[self.pos]
    if c == ' ' || c == '\t' {
      self.pos = self.pos + 1
    } else {
      break
    }
  }
}

///|
fn EvalState::current(self : EvalState) -> Char {
  if self.pos < self.chars.length() {
    self.chars[self.pos]
  } else {
    '\x00'
  }
}

///|
fn EvalState::parse_expr(self : EvalState) -> Result[Double, String] {
  self.parse_additive()
}

///|
fn EvalState::parse_additive(self : EvalState) -> Result[Double, String] {
  let left = self.parse_multiplicative()
  match left {
    Err(e) => Err(e)
    Ok(initial) => {
      let mut val = initial
      while true {
        self.skip_whitespace()
        let c = self.current()
        if c == '+' {
          self.pos = self.pos + 1
          match self.parse_multiplicative() {
            Ok(r) => val = val + r
            Err(e) => return Err(e)
          }
        } else if c == '-' {
          self.pos = self.pos + 1
          match self.parse_multiplicative() {
            Ok(r) => val = val - r
            Err(e) => return Err(e)
          }
        } else {
          break
        }
      }
      Ok(val)
    }
  }
}

///|
fn EvalState::parse_multiplicative(self : EvalState) -> Result[Double, String] {
  let left = self.parse_primary()
  match left {
    Err(e) => Err(e)
    Ok(initial) => {
      let mut val = initial
      while true {
        self.skip_whitespace()
        let c = self.current()
        if c == '*' {
          self.pos = self.pos + 1
          match self.parse_primary() {
            Ok(r) => val = val * r
            Err(e) => return Err(e)
          }
        } else if c == '/' {
          self.pos = self.pos + 1
          match self.parse_primary() {
            Ok(r) =>
              if r == 0.0 {
                return Err("Division by zero")
              } else {
                val = val / r
              }
            Err(e) => return Err(e)
          }
        } else {
          break
        }
      }
      Ok(val)
    }
  }
}

///|
fn EvalState::parse_primary(self : EvalState) -> Result[Double, String] {
  self.skip_whitespace()
  let c = self.current()
  // Handle negative
  if c == '-' {
    self.pos = self.pos + 1
    match self.parse_primary() {
      Ok(v) => return Ok(-v)
      Err(e) => return Err(e)
    }
  }
  // Handle parentheses
  if c == '(' {
    self.pos = self.pos + 1
    let result = self.parse_expr()
    match result {
      Err(e) => return Err(e)
      Ok(v) => {
        self.skip_whitespace()
        if self.current() == ')' {
          self.pos = self.pos + 1
          return Ok(v)
        } else {
          return Err("Expected closing parenthesis")
        }
      }
    }
  }
  // Parse number
  self.parse_number()
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn EvalState::parse_number(self : EvalState) -> Result[Double, String] {
  let start = self.pos
  let mut has_dot = false
  while self.pos < self.chars.length() {
    let c = self.chars[self.pos]
    if is_digit(c) {
      self.pos = self.pos + 1
    } else if c == '.' && not(has_dot) {
      has_dot = true
      self.pos = self.pos + 1
    } else {
      break
    }
  }
  if self.pos == start {
    return Err("Expected number")
  }
  let mut num_str = ""
  for i = start; i < self.pos; i = i + 1 {
    num_str = num_str + self.chars[i].to_string()
  }
  let parsed = @strconv.parse_double(num_str) catch { _ => return Err("Invalid number") }
  Ok(parsed)
}

///|
/// Base64 encode
pub fn UtilityToolPlugin::base64_encode(
  _self : UtilityToolPlugin,
  input : String,
) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let bytes = input.to_array()
  let mut result = ""
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i].to_int()
    let b1 = if i + 1 < bytes.length() { bytes[i + 1].to_int() } else { 0 }
    let b2 = if i + 2 < bytes.length() { bytes[i + 2].to_int() } else { 0 }
    let c0 = b0 >> 2
    let c1 = ((b0 & 3) << 4) | (b1 >> 4)
    let c2 = ((b1 & 15) << 2) | (b2 >> 6)
    let c3 = b2 & 63
    result = result + alphabet.substring(start=c0, end=c0 + 1)
    result = result + alphabet.substring(start=c1, end=c1 + 1)
    if i + 1 < bytes.length() {
      result = result + alphabet.substring(start=c2, end=c2 + 1)
    } else {
      result = result + "="
    }
    if i + 2 < bytes.length() {
      result = result + alphabet.substring(start=c3, end=c3 + 1)
    } else {
      result = result + "="
    }
    i = i + 3
  }
  result
}

///|
/// Handle JSON-RPC request
pub fn UtilityToolPlugin::handle_request(
  self : UtilityToolPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "calculate" => self.handle_calculate(request)
    "random_int" => self.handle_random_int(request)
    "random_float" => self.handle_random_float(request)
    "uuid" => self.handle_uuid(request)
    "base64_encode" => self.handle_base64_encode(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn UtilityToolPlugin::handle_calculate(
  self : UtilityToolPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let expr = match request.params {
    Some({ "expression": String(e), .. }) => e
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'expression' parameter",
        id=request.id,
      )
  }
  let result = self.calculate(expr)
  if result.success {
    @interfaces.JsonRpcResponse::success(
      result={
        "expression": Json::string(result.expression),
        "result": Json::number(result.result),
      },
      id=request.id,
    )
  } else {
    @interfaces.JsonRpcResponse::error(
      code=@interfaces.jsonrpc_error_internal_error(),
      message=result.error.or("Calculation failed"),
      id=request.id,
    )
  }
}

///|
fn UtilityToolPlugin::handle_random_int(
  self : UtilityToolPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (min, max) = match request.params {
    Some({ "min": Number(mi, ..), "max": Number(ma, ..), .. }) =>
      (mi.to_int(), ma.to_int())
    _ => (0, 100)
  }
  let result = self.random_int(min, max)
  @interfaces.JsonRpcResponse::success(
    result={ "value": Json::number(result.to_double()) },
    id=request.id,
  )
}

///|
fn UtilityToolPlugin::handle_random_float(
  self : UtilityToolPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let result = self.random_float()
  @interfaces.JsonRpcResponse::success(
    result={ "value": Json::number(result) },
    id=request.id,
  )
}

///|
fn UtilityToolPlugin::handle_uuid(
  self : UtilityToolPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let uuid = self.uuid_v4()
  @interfaces.JsonRpcResponse::success(
    result={ "uuid": Json::string(uuid) },
    id=request.id,
  )
}

///|
fn UtilityToolPlugin::handle_base64_encode(
  self : UtilityToolPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let input = match request.params {
    Some({ "input": String(s), .. }) => s
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'input' parameter",
        id=request.id,
      )
  }
  let encoded = self.base64_encode(input)
  @interfaces.JsonRpcResponse::success(
    result={ "encoded": Json::string(encoded) },
    id=request.id,
  )
}
