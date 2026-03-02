///|
/// Digest Module Tests
/// Note: This is a blackbox test file - only public API can be tested

test "DigestServiceConfig default values" {
  let config = @trace.DigestServiceConfig::default()
  assert_eq(config.iterative.max_iterations, 5)
  assert_eq(config.iterative.target_ratio, 0.3)
  assert_eq(config.batch.max_batch_size, 5)
}

test "DigestService creation" {
  let service = @trace.DigestService::with_defaults()
  assert_eq(service.config.iterative.convergence_threshold, 0.05)
}

test "DigestContextType variants" {
  assert_eq(@trace.DigestContextType::Conversation.to_string(), "Conversation")
  assert_eq(@trace.DigestContextType::Document.to_string(), "Document")
  assert_eq(@trace.DigestContextType::Notes.to_string(), "Notes")
}

test "DigestError display" {
  let err : @trace.DigestError = @trace.DigestError::EmptyInput
  assert_true(err.to_string().contains("EmptyInput"))
  let err2 : @trace.DigestError = @trace.DigestError::ModelCallError("test")
  assert_true(err2.to_string().contains("ModelCallError"))
}

test "estimate_tokens calculation" {
  // 空文字列
  assert_eq(@trace.estimate_tokens(""), 0)
  // 2文字 = 1トークン
  assert_eq(@trace.estimate_tokens("ab"), 1)
  // 4文字 = 2トークン
  assert_eq(@trace.estimate_tokens("abcd"), 2)
  // 5文字 = 3トークン (切り上げ)
  assert_eq(@trace.estimate_tokens("abcde"), 3)
}

test "IterativeDigestConfig default values" {
  let config = @trace.IterativeDigestConfig::default()
  assert_eq(config.target_ratio, 0.3)
  assert_eq(config.max_iterations, 5)
  assert_eq(config.convergence_threshold, 0.05)
}

test "BatchDigestConfig default values" {
  let config = @trace.BatchDigestConfig::default()
  assert_eq(config.batch_threshold, 300)
  assert_eq(config.max_batch_size, 5)
  assert_eq(config.max_batch_chars, 1500)
}
