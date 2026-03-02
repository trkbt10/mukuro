///|
/// NCD (Normalized Compression Distance) Implementation
/// Measures semantic similarity between texts using deflate compression
///
/// NCD(x, y) = (C(xy) - min(C(x), C(y))) / max(C(x), C(y))
/// where C(x) is the compressed size of x
///
/// Value range: 0 (identical) to ~1 (completely different)

///|
/// Get compressed size of text
/// Returns compressed size in bytes, or -1 on error
pub fn compressed_size(text : String) -> Int64 {
  let bytes = @utf8.encode(text)
  c_deflate_size(bytes, bytes.length().to_int64())
}

///|
/// Get compressed size of bytes
pub fn compressed_size_bytes(bytes : Bytes) -> Int64 {
  c_deflate_size(bytes, bytes.length().to_int64())
}

///|
/// Calculate NCD between two texts
/// Returns: 0.0 (identical) to ~1.0 (completely different)
/// Returns 0.0 if both texts are empty
/// Returns 1.0 if one text is empty and the other is not
pub fn ncd(a : String, b : String) -> Double {
  // Handle edge cases
  if a == "" && b == "" {
    return 0.0
  }
  if a == "" || b == "" {
    return 1.0
  }

  // Get individual compressed sizes
  let c_a = compressed_size(a)
  let c_b = compressed_size(b)

  // Handle compression errors
  if c_a < 0L || c_b < 0L {
    return 1.0
  }

  // Get compressed size of concatenation
  let ab = a + b
  let c_ab = compressed_size(ab)
  if c_ab < 0L {
    return 1.0
  }

  // Calculate NCD
  let min_c = if c_a < c_b { c_a } else { c_b }
  let max_c = if c_a > c_b { c_a } else { c_b }

  // Avoid division by zero
  if max_c == 0L {
    return 0.0
  }

  let numerator = c_ab.to_double() - min_c.to_double()
  let denominator = max_c.to_double()
  numerator / denominator
}

///|
/// Calculate NCD between two byte arrays
pub fn ncd_bytes(a : Bytes, b : Bytes) -> Double {
  // Handle edge cases
  if a.length() == 0 && b.length() == 0 {
    return 0.0
  }
  if a.length() == 0 || b.length() == 0 {
    return 1.0
  }

  // Get individual compressed sizes
  let c_a = compressed_size_bytes(a)
  let c_b = compressed_size_bytes(b)

  // Handle compression errors
  if c_a < 0L || c_b < 0L {
    return 1.0
  }

  // Concatenate bytes
  let ab = Bytes::makei(a.length() + b.length(), fn(i) {
    if i < a.length() {
      a[i]
    } else {
      b[i - a.length()]
    }
  })
  let c_ab = compressed_size_bytes(ab)
  if c_ab < 0L {
    return 1.0
  }

  // Calculate NCD
  let min_c = if c_a < c_b { c_a } else { c_b }
  let max_c = if c_a > c_b { c_a } else { c_b }

  // Avoid division by zero
  if max_c == 0L {
    return 0.0
  }

  let numerator = c_ab.to_double() - min_c.to_double()
  let denominator = max_c.to_double()
  numerator / denominator
}

///|
/// Calculate NCD values for adjacent pairs in an array
/// Returns array of NCD values where result[i] = ncd(texts[i], texts[i+1])
pub fn calculate_adjacent_ncd(texts : Array[String]) -> Array[Double] {
  if texts.length() < 2 {
    return []
  }
  let result : Array[Double] = Array::make(texts.length() - 1, 0.0)
  for i = 0; i < texts.length() - 1; i = i + 1 {
    result[i] = ncd(texts[i], texts[i + 1])
  }
  result
}

///|
/// Find local maxima in NCD values
/// Returns indices where the value is greater than neighbors and above threshold
pub fn find_local_maxima(
  ncd_values : Array[Double],
  threshold : Double,
) -> Array[Int] {
  let maxima : Array[Int] = []
  for i = 0; i < ncd_values.length(); i = i + 1 {
    let value = ncd_values[i]
    if value < threshold {
      continue
    }

    // Check if it's a local maximum
    let is_max = if i == 0 {
      // First element: only check right neighbor
      ncd_values.length() == 1 || value >= ncd_values[1]
    } else if i == ncd_values.length() - 1 {
      // Last element: only check left neighbor
      value > ncd_values[i - 1]
    } else {
      // Middle: check both neighbors
      value > ncd_values[i - 1] && value >= ncd_values[i + 1]
    }
    if is_max {
      maxima.push(i)
    }
  }
  maxima
}

///|
/// Calculate NCD for sliding windows of sentences
/// window_size: number of sentences per window
/// Returns NCD values between adjacent windows
pub fn sliding_window_ncd(
  sentences : Array[String],
  window_size : Int,
) -> Array[Double] {
  if sentences.length() < window_size + 1 {
    return []
  }

  let num_windows = sentences.length() - window_size + 1
  let result : Array[Double] = Array::make(num_windows - 1, 0.0)

  for i = 0; i < num_windows - 1; i = i + 1 {
    // Build window 1: sentences[i..i+window_size]
    let mut window1 = ""
    for j = 0; j < window_size; j = j + 1 {
      if j > 0 {
        window1 = window1 + " "
      }
      window1 = window1 + sentences[i + j]
    }

    // Build window 2: sentences[i+1..i+1+window_size]
    let mut window2 = ""
    for j = 0; j < window_size; j = j + 1 {
      if j > 0 {
        window2 = window2 + " "
      }
      window2 = window2 + sentences[i + 1 + j]
    }

    result[i] = ncd(window1, window2)
  }

  result
}

// ============================================================
// Internal Tests (moved from ncd_test.mbt for zlib linking)
// ============================================================

///|
test "ncd of identical strings is close to 0" {
  let text = "This is a test string for NCD calculation"
  let result = ncd(text, text)
  assert_true(result >= 0.0 && result < 0.3)
}

///|
test "ncd of empty strings is 0" {
  let result = ncd("", "")
  assert_eq(result, 0.0)
}

///|
test "ncd with one empty string is 1" {
  let result1 = ncd("hello", "")
  let result2 = ncd("", "world")
  assert_eq(result1, 1.0)
  assert_eq(result2, 1.0)
}

///|
test "ncd of similar strings is lower than dissimilar" {
  let base = "The quick brown fox jumps over the lazy dog"
  let similar = "The quick brown fox leaps over the lazy dog"
  let different = "Lorem ipsum dolor sit amet consectetur adipiscing elit"
  let ncd_similar = ncd(base, similar)
  let ncd_different = ncd(base, different)
  assert_true(ncd_similar < ncd_different)
}

///|
test "ncd is symmetric" {
  let a = "Hello world"
  let b = "Goodbye world"
  let ncd_ab = ncd(a, b)
  let ncd_ba = ncd(b, a)
  assert_eq(ncd_ab, ncd_ba)
}

///|
test "ncd returns values in valid range" {
  let texts = [
    "Short", "A bit longer text", "This is a much longer text with more content to compress",
    "日本語のテキスト", "Mixed text with 日本語 and English",
  ]
  for i = 0; i < texts.length(); i = i + 1 {
    for j = i + 1; j < texts.length(); j = j + 1 {
      let result = ncd(texts[i], texts[j])
      assert_true(result >= 0.0 && result <= 1.5)
    }
  }
}

///|
test "calculate_adjacent_ncd returns correct length" {
  let texts = ["a", "b", "c", "d"]
  let result = calculate_adjacent_ncd(texts)
  assert_eq(result.length(), 3)
}

///|
test "calculate_adjacent_ncd with less than 2 texts" {
  let result1 = calculate_adjacent_ncd([])
  let result2 = calculate_adjacent_ncd(["single"])
  assert_eq(result1.length(), 0)
  assert_eq(result2.length(), 0)
}

///|
test "find_local_maxima with no peaks above threshold" {
  let values = [0.1, 0.2, 0.15, 0.1]
  let result = find_local_maxima(values, 0.5)
  assert_eq(result.length(), 0)
}

///|
test "find_local_maxima finds peaks" {
  let values = [0.1, 0.5, 0.2, 0.6, 0.3]
  let result = find_local_maxima(values, 0.3)
  assert_eq(result.length(), 2)
  assert_eq(result[0], 1)
  assert_eq(result[1], 3)
}

///|
test "find_local_maxima handles plateau" {
  let values = [0.1, 0.5, 0.5, 0.2]
  let result = find_local_maxima(values, 0.3)
  assert_true(result.length() >= 1)
  assert_eq(result[0], 1)
}

///|
test "sliding_window_ncd returns correct length" {
  let sentences = [
    "Sentence one.", "Sentence two.", "Sentence three.", "Sentence four.", "Sentence five.",
  ]
  let result = sliding_window_ncd(sentences, 2)
  assert_eq(result.length(), 3)
}

///|
test "sliding_window_ncd with insufficient sentences" {
  let sentences = ["Only one."]
  let result = sliding_window_ncd(sentences, 2)
  assert_eq(result.length(), 0)
}

///|
test "compressed_size returns positive value" {
  let text = "Hello, World! This is a test."
  let size = compressed_size(text)
  assert_true(size > 0L)
}

///|
test "compressed_size of empty string is 0" {
  let size = compressed_size("")
  assert_eq(size, 0L)
}
