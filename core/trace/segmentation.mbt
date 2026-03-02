///|
/// NCD + TF-IDF Combined Segmentation
/// Combines compression-based (NCD) and lexical (TF-IDF) distance measures
/// for more robust semantic boundary detection.
///
/// Based on: zakoducthunt/packages/@zako-fish/core/src/text-processing/docs-segmentation/ncd-tfidf-strategy

// ============================================================
// Math Utilities (not available in standard library)
// ============================================================

///|
/// Square root using Newton's method
fn sqrt(x : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  let mut guess = x / 2.0
  for _i = 0; _i < 20; _i = _i + 1 {
    guess = (guess + x / guess) / 2.0
  }
  guess
}

///|
/// Natural logarithm approximation
/// Uses the identity: ln(x) = 2 * (y + y^3/3 + y^5/5 + ...) where y = (x-1)/(x+1)
fn log(x : Double) -> Double {
  if x <= 0.0 {
    return -1.0e308 // Approximation of negative infinity
  }
  if x == 1.0 {
    return 0.0
  }
  // Reduce x to range [0.5, 2] by factoring out powers of 2
  let mut value = x
  let mut exp_adj = 0.0
  let ln2 = 0.6931471805599453 // ln(2)
  while value > 2.0 {
    value = value / 2.0
    exp_adj = exp_adj + ln2
  }
  while value < 0.5 {
    value = value * 2.0
    exp_adj = exp_adj - ln2
  }
  // Now compute ln(value) for value in [0.5, 2]
  let y = (value - 1.0) / (value + 1.0)
  let y2 = y * y
  let mut term = y
  let mut sum = y
  for i = 1; i < 20; i = i + 1 {
    term = term * y2
    let n = (2 * i + 1).to_double()
    sum = sum + term / n
  }
  2.0 * sum + exp_adj
}

// ============================================================
// TF-IDF Types and Structures
// ============================================================

///|
/// TF-IDF Vector (sparse representation)
priv struct TfidfVector {
  /// Token -> TF-IDF value
  values : Map[String, Double]
  /// L2 norm for normalization
  norm : Double
}

///|
/// NCD + TF-IDF Combined Config
pub(all) struct NcdTfidfConfig {
  /// NCD weight in combined score (0.0-1.0)
  ncd_weight : Double
  /// TF-IDF weight in combined score (0.0-1.0)
  tfidf_weight : Double
  /// Use character bigrams for better Japanese support
  use_char_bigrams : Bool
  /// Minimum token length for word tokens
  min_token_length : Int
  /// Window size for sliding window
  window_size : Int
  /// Size constraints
  min_segment_size : Int
  target_segment_size : Int
  max_segment_size : Int
  /// Threshold percentile for boundary detection (0.0-1.0)
  threshold_percentile : Double
}

///|
pub fn NcdTfidfConfig::default() -> NcdTfidfConfig {
  {
    ncd_weight: 0.5,
    tfidf_weight: 0.5,
    use_char_bigrams: true,
    min_token_length: 2,
    window_size: 3,
    min_segment_size: 100,
    target_segment_size: 500,
    max_segment_size: 2000,
    threshold_percentile: 0.75,
  }
}

// ============================================================
// Tokenization
// ============================================================

///|
/// Check if a character is a word character (alphanumeric or CJK)
fn is_word_char(c : Char) -> Bool {
  let code = c.to_int()
  // ASCII alphanumeric
  (code >= 0x30 && code <= 0x39) || // 0-9
  (code >= 0x41 && code <= 0x5A) || // A-Z
  (code >= 0x61 && code <= 0x7A) || // a-z
  // CJK ranges
  (code >= 0x4E00 && code <= 0x9FFF) || // CJK Unified
  (code >= 0x3040 && code <= 0x309F) || // Hiragana
  (code >= 0x30A0 && code <= 0x30FF) // Katakana
}

///|
/// Tokenize text into words (split on non-word characters)
fn tokenize_words(text : String, min_length : Int) -> Array[String] {
  let tokens : Array[String] = []
  let current = StringBuilder::new()
  for c in text {
    if is_word_char(c) {
      current.write_char(c)
    } else {
      let word = current.to_string().to_lower()
      if word.iter().count() >= min_length {
        tokens.push(word)
      }
      current.reset()
    }
  }
  // Handle last word
  let last_word = current.to_string().to_lower()
  if last_word.iter().count() >= min_length {
    tokens.push(last_word)
  }
  tokens
}

///|
/// Generate character bigrams from text
fn generate_char_bigrams(text : String) -> Array[String] {
  let bigrams : Array[String] = []
  let chars : Array[Char] = []
  for c in text {
    if is_word_char(c) {
      chars.push(c)
    }
  }
  for i = 0; i < chars.length() - 1; i = i + 1 {
    let bigram = StringBuilder::new()
    bigram.write_char(chars[i])
    bigram.write_char(chars[i + 1])
    bigrams.push(bigram.to_string())
  }
  bigrams
}

///|
/// Combined tokenization: words + optional character bigrams
fn tokenize(text : String, config : NcdTfidfConfig) -> Array[String] {
  let words = tokenize_words(text, config.min_token_length)
  if config.use_char_bigrams {
    let bigrams = generate_char_bigrams(text)
    let combined : Array[String] = []
    for w in words {
      combined.push(w)
    }
    for b in bigrams {
      combined.push("_bg_" + b) // Prefix to distinguish from words
    }
    combined
  } else {
    words
  }
}

// ============================================================
// TF-IDF Calculation
// ============================================================

///|
/// Count term frequencies in a document
fn count_term_freqs(tokens : Array[String]) -> Map[String, Int] {
  let freqs : Map[String, Int] = {}
  for token in tokens {
    match freqs.get(token) {
      Some(count) => freqs.set(token, count + 1)
      None => freqs.set(token, 1)
    }
  }
  freqs
}

///|
/// Calculate IDF values from a corpus of documents
fn calculate_idf(docs : Array[Array[String]]) -> Map[String, Double] {
  let doc_count = docs.length()
  if doc_count == 0 {
    return {}
  }
  // Count document frequency for each term
  let doc_freqs : Map[String, Int] = {}
  for doc in docs {
    let seen : Map[String, Bool] = {}
    for token in doc {
      if not(seen.contains(token)) {
        seen.set(token, true)
        match doc_freqs.get(token) {
          Some(count) => doc_freqs.set(token, count + 1)
          None => doc_freqs.set(token, 1)
        }
      }
    }
  }
  // Calculate IDF: log(N / df)
  let idf : Map[String, Double] = {}
  let n = doc_count.to_double()
  for entry in doc_freqs {
    let df = entry.1.to_double()
    // Add 1 to avoid division by zero, use log1p for numerical stability
    idf.set(entry.0, log((n + 1.0) / (df + 1.0)) + 1.0)
  }
  idf
}

///|
/// Build TF-IDF vector for a document
fn build_tfidf_vector(
  tokens : Array[String],
  idf : Map[String, Double],
) -> TfidfVector {
  let tf_freqs = count_term_freqs(tokens)
  let doc_len = tokens.length().to_double()
  if doc_len == 0.0 {
    return { values: {}, norm: 0.0 }
  }
  let values : Map[String, Double] = {}
  let mut sum_sq = 0.0
  for entry in tf_freqs {
    let tf = entry.1.to_double() / doc_len
    let idf_val = match idf.get(entry.0) {
      Some(v) => v
      None => 1.0
    }
    let tfidf = tf * idf_val
    values.set(entry.0, tfidf)
    sum_sq = sum_sq + tfidf * tfidf
  }
  { values, norm: sqrt(sum_sq) }
}

///|
/// Calculate cosine similarity between two TF-IDF vectors
fn cosine_similarity(v1 : TfidfVector, v2 : TfidfVector) -> Double {
  if v1.norm == 0.0 || v2.norm == 0.0 {
    return 0.0
  }
  let mut dot_product = 0.0
  for entry in v1.values {
    match v2.values.get(entry.0) {
      Some(val2) => dot_product = dot_product + entry.1 * val2
      None => ()
    }
  }
  dot_product / (v1.norm * v2.norm)
}

///|
/// Calculate cosine distance (1 - similarity)
fn cosine_distance(v1 : TfidfVector, v2 : TfidfVector) -> Double {
  1.0 - cosine_similarity(v1, v2)
}

// ============================================================
// Min-Max Normalization
// ============================================================

///|
/// Normalize values to [0, 1] range using min-max normalization
fn min_max_normalize(values : Array[Double]) -> Array[Double] {
  if values.length() == 0 {
    return []
  }
  let mut min_val = values[0]
  let mut max_val = values[0]
  for v in values {
    if v < min_val {
      min_val = v
    }
    if v > max_val {
      max_val = v
    }
  }
  let range = max_val - min_val
  if range == 0.0 {
    // All values are the same
    return Array::make(values.length(), 0.5)
  }
  values.map(fn(v) { (v - min_val) / range })
}

// ============================================================
// Combined NCD + TF-IDF Distance
// ============================================================

///|
/// Calculate combined NCD + TF-IDF distance for sliding windows
pub fn calculate_window_ncd_tfidf_distances(
  sentences : Array[String],
  config : NcdTfidfConfig,
) -> Array[Double] {
  let window_size = config.window_size
  if sentences.length() < window_size + 1 {
    return []
  }
  let num_windows = sentences.length() - window_size + 1
  if num_windows < 2 {
    return []
  }
  // Build windows
  let windows : Array[String] = []
  for i = 0; i < num_windows; i = i + 1 {
    let buf = StringBuilder::new()
    for j = 0; j < window_size; j = j + 1 {
      if j > 0 {
        buf.write_string(" ")
      }
      buf.write_string(sentences[i + j])
    }
    windows.push(buf.to_string())
  }
  // Calculate NCD distances between adjacent windows
  let ncd_distances : Array[Double] = []
  for i = 0; i < windows.length() - 1; i = i + 1 {
    let ncd_val = @compression.ncd(windows[i], windows[i + 1])
    ncd_distances.push(ncd_val)
  }
  // Tokenize windows for TF-IDF
  let tokenized_windows : Array[Array[String]] = []
  for window in windows {
    tokenized_windows.push(tokenize(window, config))
  }
  // Calculate IDF across all windows
  let idf = calculate_idf(tokenized_windows)
  // Build TF-IDF vectors
  let tfidf_vectors : Array[TfidfVector] = []
  for tokens in tokenized_windows {
    tfidf_vectors.push(build_tfidf_vector(tokens, idf))
  }
  // Calculate TF-IDF distances between adjacent windows
  let tfidf_distances : Array[Double] = []
  for i = 0; i < tfidf_vectors.length() - 1; i = i + 1 {
    let dist = cosine_distance(tfidf_vectors[i], tfidf_vectors[i + 1])
    tfidf_distances.push(dist)
  }
  // Normalize both distance arrays
  let ncd_normalized = min_max_normalize(ncd_distances)
  let tfidf_normalized = min_max_normalize(tfidf_distances)
  // Combine with weights
  let combined : Array[Double] = []
  for i = 0; i < ncd_normalized.length(); i = i + 1 {
    let combined_val = config.ncd_weight * ncd_normalized[i] +
      config.tfidf_weight * tfidf_normalized[i]
    combined.push(combined_val)
  }
  combined
}

// ============================================================
// Boundary Detection
// ============================================================

///|
/// Find boundaries based on combined distance scores
fn find_boundaries(
  distances : Array[Double],
  threshold_percentile : Double,
) -> Array[Int] {
  if distances.length() == 0 {
    return []
  }
  // Sort distances to find percentile threshold
  let sorted : Array[Double] = []
  for d in distances {
    sorted.push(d)
  }
  // Simple bubble sort (sufficient for small arrays)
  for i = 0; i < sorted.length(); i = i + 1 {
    for j = i + 1; j < sorted.length(); j = j + 1 {
      if sorted[j] < sorted[i] {
        let temp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = temp
      }
    }
  }
  // Find threshold at percentile
  let threshold_idx = ((sorted.length().to_double() - 1.0) *
  threshold_percentile).to_int()
  let threshold = sorted[threshold_idx]
  // Find local maxima above threshold
  let boundaries : Array[Int] = []
  for i = 0; i < distances.length(); i = i + 1 {
    let val = distances[i]
    if val < threshold {
      continue
    }
    // Check if local maximum
    let is_max = if i == 0 {
      distances.length() == 1 || val >= distances[1]
    } else if i == distances.length() - 1 {
      val > distances[i - 1]
    } else {
      val > distances[i - 1] && val >= distances[i + 1]
    }
    if is_max {
      boundaries.push(i)
    }
  }
  boundaries
}

// ============================================================
// Sentence Splitting
// ============================================================

///|
/// Split text into sentences
pub fn split_sentences(text : String) -> Array[Sentence] {
  let sentences : Array[Sentence] = []
  let current = StringBuilder::new()
  let mut start = 0
  let mut pos = 0
  let mut idx = 0
  for c in text {
    current.write_char(c)
    pos = pos + 1
    // Check for sentence-ending punctuation
    let is_end = c == '.' ||
      c == '!' ||
      c == '?' ||
      c == '。' ||
      c == '！' ||
      c == '？' ||
      c == '\n'
    if is_end {
      let sentence_text = current.to_string().trim(chars=" \t\n\r").to_string()
      if sentence_text.iter().count() > 0 {
        sentences.push({ index: idx, text: sentence_text, start, end: pos })
        idx = idx + 1
      }
      start = pos
      current.reset()
    }
  }
  // Handle remaining text
  let remaining = current.to_string().trim(chars=" \t\n\r").to_string()
  if remaining.iter().count() > 0 {
    sentences.push({ index: idx, text: remaining, start, end: pos })
  }
  sentences
}

// ============================================================
// Main Segmentation Function
// ============================================================

///|
/// Segment result
pub(all) struct SegmentResult {
  /// Segmented text chunks
  chunks : Array[String]
  /// Boundary positions (sentence indices)
  boundaries : Array[Int]
  /// Combined distance scores
  distances : Array[Double]
}

///|
/// Segment text using NCD + TF-IDF combined strategy
pub fn segment_by_ncd_tfidf(
  text : String,
  config : NcdTfidfConfig,
) -> SegmentResult {
  let sentences = split_sentences(text)
  if sentences.length() == 0 {
    return { chunks: [], boundaries: [], distances: [] }
  }
  if sentences.length() == 1 {
    return { chunks: [sentences[0].text], boundaries: [], distances: [] }
  }
  // Extract sentence texts
  let sentence_texts : Array[String] = []
  for s in sentences {
    sentence_texts.push(s.text)
  }
  // Calculate combined distances
  let distances = calculate_window_ncd_tfidf_distances(sentence_texts, config)
  if distances.length() == 0 {
    // Not enough sentences for windowed analysis, return as single chunk
    let buf = StringBuilder::new()
    for i, s in sentences {
      if i > 0 {
        buf.write_string(" ")
      }
      buf.write_string(s.text)
    }
    return { chunks: [buf.to_string()], boundaries: [], distances: [] }
  }
  // Find semantic boundaries
  let raw_boundaries = find_boundaries(distances, config.threshold_percentile)
  // Convert boundary indices to sentence indices
  // Distance[i] is between window starting at sentence i and window starting at sentence i+1
  // So boundary at distance[i] means split after sentence (i + config.window_size - 1)
  let sentence_boundaries : Array[Int] = []
  for b in raw_boundaries {
    let sentence_idx = b + config.window_size - 1
    if sentence_idx < sentences.length() - 1 {
      sentence_boundaries.push(sentence_idx)
    }
  }
  // Apply size constraints and build chunks
  let chunks = build_chunks_with_constraints(
    sentences, sentence_boundaries, config,
  )
  { chunks, boundaries: sentence_boundaries, distances }
}

///|
/// Build chunks respecting size constraints
fn build_chunks_with_constraints(
  sentences : Array[Sentence],
  boundaries : Array[Int],
  config : NcdTfidfConfig,
) -> Array[String] {
  if sentences.length() == 0 {
    return []
  }
  // Add implicit boundaries at start and end
  let all_boundaries : Array[Int] = [0]
  for b in boundaries {
    if b > 0 && b < sentences.length() - 1 {
      all_boundaries.push(b + 1) // Start of next segment
    }
  }
  all_boundaries.push(sentences.length())
  let chunks : Array[String] = []
  for i = 0; i < all_boundaries.length() - 1; i = i + 1 {
    let start_idx = all_boundaries[i]
    let end_idx = all_boundaries[i + 1]
    // Build chunk text
    let chunk_buf = StringBuilder::new()
    for j = start_idx; j < end_idx; j = j + 1 {
      if j > start_idx {
        chunk_buf.write_string(" ")
      }
      chunk_buf.write_string(sentences[j].text)
    }
    let chunk_text = chunk_buf.to_string()
    let chunk_len = chunk_text.iter().count()
    // Handle size constraints
    if chunk_len < config.min_segment_size && chunks.length() > 0 {
      // Merge with previous chunk if too small
      let prev = chunks.pop()
      match prev {
        Some(prev_text) => chunks.push(prev_text + " " + chunk_text)
        None => chunks.push(chunk_text)
      }
    } else if chunk_len > config.max_segment_size {
      // Split oversized chunks (simple split by target size)
      let sub_chunks = split_oversized_chunk(
        chunk_text,
        config.target_segment_size,
        config.min_segment_size,
      )
      for sc in sub_chunks {
        chunks.push(sc)
      }
    } else {
      chunks.push(chunk_text)
    }
  }
  chunks
}

///|
/// Split an oversized chunk into smaller pieces
fn split_oversized_chunk(
  text : String,
  target_size : Int,
  min_size : Int,
) -> Array[String] {
  let result : Array[String] = []
  let sentences = split_sentences(text)
  if sentences.length() <= 1 {
    result.push(text)
    return result
  }
  let current = StringBuilder::new()
  let mut current_len = 0
  for s in sentences {
    let s_len = s.text.iter().count()
    if current_len > 0 && current_len + s_len > target_size {
      let chunk = current.to_string()
      if chunk.iter().count() >= min_size {
        result.push(chunk)
        current.reset()
        current_len = 0
      }
    }
    if current_len > 0 {
      current.write_string(" ")
      current_len = current_len + 1
    }
    current.write_string(s.text)
    current_len = current_len + s_len
  }
  // Handle remaining
  let remaining = current.to_string()
  if remaining.iter().count() > 0 {
    if remaining.iter().count() < min_size && result.length() > 0 {
      // Merge with last chunk
      let last = result.pop()
      match last {
        Some(last_text) => result.push(last_text + " " + remaining)
        None => result.push(remaining)
      }
    } else {
      result.push(remaining)
    }
  }
  result
}

// ============================================================
// Internal Tests
// ============================================================

///|
test "is_word_char identifies ASCII alphanumeric" {
  assert_true(is_word_char('a'))
  assert_true(is_word_char('Z'))
  assert_true(is_word_char('5'))
  assert_false(is_word_char(' '))
  assert_false(is_word_char('.'))
}

///|
test "is_word_char identifies CJK" {
  assert_true(is_word_char('日'))
  assert_true(is_word_char('あ'))
  assert_true(is_word_char('ア'))
}

///|
test "tokenize_words splits on non-word characters" {
  let tokens = tokenize_words("Hello, world! This is a test.", 2)
  assert_true(tokens.contains("hello"))
  assert_true(tokens.contains("world"))
  assert_true(tokens.contains("this"))
  assert_true(tokens.contains("test"))
  assert_false(tokens.contains("a")) // Too short
}

///|
test "generate_char_bigrams creates bigrams" {
  let bigrams = generate_char_bigrams("abc")
  assert_eq(bigrams.length(), 2)
  assert_eq(bigrams[0], "ab")
  assert_eq(bigrams[1], "bc")
}

///|
test "generate_char_bigrams handles Japanese" {
  let bigrams = generate_char_bigrams("日本語")
  assert_eq(bigrams.length(), 2)
  assert_eq(bigrams[0], "日本")
  assert_eq(bigrams[1], "本語")
}

///|
test "count_term_freqs counts correctly" {
  let tokens = ["a", "b", "a", "c", "a"]
  let freqs = count_term_freqs(tokens)
  assert_eq(freqs.get("a"), Some(3))
  assert_eq(freqs.get("b"), Some(1))
  assert_eq(freqs.get("c"), Some(1))
}

///|
test "min_max_normalize normalizes to 0-1" {
  let values = [1.0, 5.0, 3.0, 2.0, 4.0]
  let normalized = min_max_normalize(values)
  assert_eq(normalized[0], 0.0) // min
  assert_eq(normalized[1], 1.0) // max
  assert_eq(normalized[2], 0.5) // middle
}

///|
test "min_max_normalize handles same values" {
  let values = [3.0, 3.0, 3.0]
  let normalized = min_max_normalize(values)
  for v in normalized {
    assert_eq(v, 0.5)
  }
}

///|
test "split_sentences splits on punctuation" {
  let sentences = split_sentences("Hello. World! How are you?")
  assert_eq(sentences.length(), 3)
  assert_eq(sentences[0].text, "Hello.")
  assert_eq(sentences[1].text, "World!")
  assert_eq(sentences[2].text, "How are you?")
}

///|
test "split_sentences handles Japanese" {
  let sentences = split_sentences("こんにちは。元気ですか？")
  assert_eq(sentences.length(), 2)
  assert_eq(sentences[0].text, "こんにちは。")
  assert_eq(sentences[1].text, "元気ですか？")
}

///|
test "cosine_similarity of identical vectors is 1" {
  // Use normalized vector [0.6, 0.8] where norm = sqrt(0.36 + 0.64) = 1.0
  let v1 : TfidfVector = { values: { "a": 0.6, "b": 0.8 }, norm: 1.0 }
  let sim = cosine_similarity(v1, v1)
  // dot product = 0.6*0.6 + 0.8*0.8 = 0.36 + 0.64 = 1.0
  // cosine = 1.0 / (1.0 * 1.0) = 1.0
  assert_true(sim > 0.99 && sim <= 1.01)
}

///|
test "cosine_similarity of orthogonal vectors is 0" {
  let v1 : TfidfVector = { values: { "a": 1.0 }, norm: 1.0 }
  let v2 : TfidfVector = { values: { "b": 1.0 }, norm: 1.0 }
  let sim = cosine_similarity(v1, v2)
  assert_eq(sim, 0.0)
}

///|
test "segment_by_ncd_tfidf handles empty text" {
  let result = segment_by_ncd_tfidf("", NcdTfidfConfig::default())
  assert_eq(result.chunks.length(), 0)
}

///|
test "segment_by_ncd_tfidf handles single sentence" {
  let result = segment_by_ncd_tfidf("Hello world.", NcdTfidfConfig::default())
  assert_eq(result.chunks.length(), 1)
  assert_eq(result.chunks[0], "Hello world.")
}

///|
test "find_boundaries finds local maxima" {
  let distances = [0.1, 0.5, 0.2, 0.8, 0.3]
  let boundaries = find_boundaries(distances, 0.5)
  assert_true(boundaries.contains(1))
  assert_true(boundaries.contains(3))
}
