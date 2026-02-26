///|
test "extract_bearer_token extracts standard bearer header" {
  inspect(extract_bearer_token("Bearer abc123"), content="Some(\"abc123\")")
}

///|
test "extract_bearer_token is case-insensitive for bearer prefix" {
  inspect(extract_bearer_token("bearer xyz"), content="Some(\"xyz\")")
}

///|
test "extract_bearer_token returns None for empty bearer token" {
  inspect(extract_bearer_token("Bearer "), content="None")
}

///|
test "extract_bearer_token passes through raw token" {
  inspect(extract_bearer_token("token-value"), content="Some(\"token-value\")")
}
