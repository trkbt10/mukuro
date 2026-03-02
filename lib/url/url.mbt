///|
/// URL parsing utilities.
/// Provides URL structure parsing, query parameter extraction, and URL encoding/decoding.

// =============================================================================
// Types
// =============================================================================

///|
/// Parsed URL components
pub struct Url {
  path : String
  query : String?
  fragment : String?
} derive(Eq, Show)

// =============================================================================
// Parsing
// =============================================================================

///|
/// Parse a URL string into its components
/// e.g. parse("/ws/chat?id=123#section") => { path: "/ws/chat", query: Some("id=123"), fragment: Some("section") }
pub fn parse(url : String) -> Url {
  let (path_and_query, fragment) = split_first(url, '#')
  let (path, query) = split_first(path_and_query, '?')
  { path, query, fragment }
}

///|
/// Extract just the path portion of a URL (before ? or #)
pub fn path(url : String) -> String {
  parse(url).path
}

///|
/// Extract the raw query string (without the leading ?)
pub fn query_string(url : String) -> String? {
  parse(url).query
}

// =============================================================================
// Query Parameters
// =============================================================================

///|
/// Parse a single query parameter from a URL
/// e.g. get_param("/ws/chat?chat_id=abc&foo=bar", "chat_id") => Some("abc")
pub fn get_param(url : String, name : String) -> String? {
  match query_string(url) {
    Some(qs) => parse_param_from_query(qs, name)
    None => None
  }
}

///|
/// Parse all query parameters into a Map
/// e.g. get_params("/ws/chat?a=1&b=2") => {"a": "1", "b": "2"}
pub fn get_params(url : String) -> Map[String, String] {
  match query_string(url) {
    Some(qs) => parse_query_to_map(qs)
    None => {}
  }
}

///|
/// Parse a query parameter from a raw query string (without leading ?)
fn parse_param_from_query(query : String, name : String) -> String? {
  for pair in query.split("&") {
    let pair_str = pair.to_string()
    let (key, value) = split_first(pair_str, '=')
    if key == name {
      return value.map(decode)
    }
  }
  None
}

///|
/// Parse a query string into a Map
fn parse_query_to_map(query : String) -> Map[String, String] {
  let result : Map[String, String] = {}
  for pair in query.split("&") {
    let pair_str = pair.to_string()
    let (key, value) = split_first(pair_str, '=')
    if key.length() > 0 {
      result[key] = value.map(decode).unwrap_or("")
    }
  }
  result
}

// =============================================================================
// Encoding / Decoding
// =============================================================================

///|
/// URL decode a string (handles %XX patterns and + as space)
pub fn decode(s : String) -> String {
  let result = StringBuilder::new()
  let chars : Array[Char] = s.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    let c = chars[i]
    if c == '%' && i + 2 < len {
      let h1 = chars[i + 1]
      let h2 = chars[i + 2]
      let code = parse_hex_digit(h1) * 16 + parse_hex_digit(h2)
      if code >= 0 {
        result.write_char(code.unsafe_to_char())
        i = i + 3
        continue
      }
    }
    if c == '+' {
      result.write_char(' ')
    } else {
      result.write_char(c)
    }
    i = i + 1
  }
  result.to_string()
}

///|
/// URL encode a string (encodes special characters as %XX)
pub fn encode(s : String) -> String {
  let result = StringBuilder::new()
  for c in s {
    if is_unreserved(c) {
      result.write_char(c)
    } else if c == ' ' {
      result.write_char('+')
    } else {
      let code = c.to_int()
      if code < 128 {
        result.write_string("%")
        result.write_string(hex_byte(code))
      } else {
        // UTF-8 encode multi-byte characters
        encode_utf8_char(result, code)
      }
    }
  }
  result.to_string()
}

// =============================================================================
// Internal Helpers
// =============================================================================

///|
/// Split string at first occurrence of delimiter
/// Returns (before, Some(after)) if found, (original, None) if not
fn split_first(s : String, delim : Char) -> (String, String?) {
  for i, c in s {
    if c == delim {
      let before = s[:i].to_string() catch { _ => return (s, None) }
      let after = s[i + 1:].to_string() catch { _ => return (before, Some("")) }
      return (before, Some(after))
    }
  }
  (s, None)
}

///|
/// Parse a single hex digit to integer, returns -1 if invalid
fn parse_hex_digit(c : Char) -> Int {
  match c {
    '0' => 0
    '1' => 1
    '2' => 2
    '3' => 3
    '4' => 4
    '5' => 5
    '6' => 6
    '7' => 7
    '8' => 8
    '9' => 9
    'a' | 'A' => 10
    'b' | 'B' => 11
    'c' | 'C' => 12
    'd' | 'D' => 13
    'e' | 'E' => 14
    'f' | 'F' => 15
    _ => -1
  }
}

///|
/// Check if character is unreserved (doesn't need encoding)
fn is_unreserved(c : Char) -> Bool {
  match c {
    'A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' | '.' | '~' => true
    _ => false
  }
}

///|
/// Convert a byte to two hex characters
fn hex_byte(b : Int) -> String {
  let hex_chars = "0123456789ABCDEF"
  let high = (b >> 4) & 0x0F
  let low = b & 0x0F
  let h = hex_chars[high:high + 1].to_string() catch { _ => "0" }
  let l = hex_chars[low:low + 1].to_string() catch { _ => "0" }
  h + l
}

///|
/// Encode a Unicode code point as UTF-8 percent-encoded bytes
fn encode_utf8_char(result : StringBuilder, code : Int) -> Unit {
  if code < 0x80 {
    result.write_string("%")
    result.write_string(hex_byte(code))
  } else if code < 0x800 {
    result.write_string("%")
    result.write_string(hex_byte(0xC0 | (code >> 6)))
    result.write_string("%")
    result.write_string(hex_byte(0x80 | (code & 0x3F)))
  } else if code < 0x10000 {
    result.write_string("%")
    result.write_string(hex_byte(0xE0 | (code >> 12)))
    result.write_string("%")
    result.write_string(hex_byte(0x80 | ((code >> 6) & 0x3F)))
    result.write_string("%")
    result.write_string(hex_byte(0x80 | (code & 0x3F)))
  } else {
    result.write_string("%")
    result.write_string(hex_byte(0xF0 | (code >> 18)))
    result.write_string("%")
    result.write_string(hex_byte(0x80 | ((code >> 12) & 0x3F)))
    result.write_string("%")
    result.write_string(hex_byte(0x80 | ((code >> 6) & 0x3F)))
    result.write_string("%")
    result.write_string(hex_byte(0x80 | (code & 0x3F)))
  }
}

// =============================================================================
// Deprecated Aliases (for backward compatibility)
// =============================================================================

///|
/// @deprecated Use get_param instead
pub fn parse_query_param(url : String, name : String) -> String? {
  get_param(url, name)
}

///|
/// @deprecated Internal helper, will be removed
pub fn find_char(s : String, c : Char) -> Int {
  for i, ch in s {
    if ch == c {
      return i
    }
  }
  -1
}
