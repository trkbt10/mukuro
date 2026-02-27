///|
/// Secret masking tests

test "is_secret_key detects token suffix" {
  assert_true(is_secret_key("api_token"))
  assert_true(is_secret_key("auth_token"))
}

test "is_secret_key detects key suffix" {
  assert_true(is_secret_key("api_key"))
  assert_true(is_secret_key("secret_key"))
  assert_true(is_secret_key("access_key"))
}

test "is_secret_key detects password suffix" {
  assert_true(is_secret_key("db_password"))
  assert_true(is_secret_key("user_password"))
}

test "is_secret_key detects credential suffix" {
  assert_true(is_secret_key("aws_credential"))
}

test "is_secret_key detects exact matches" {
  assert_true(is_secret_key("password"))
  assert_true(is_secret_key("secret"))
  assert_true(is_secret_key("token"))
  assert_true(is_secret_key("credentials"))
  assert_true(is_secret_key("private_key"))
}

test "is_secret_key is case insensitive" {
  assert_true(is_secret_key("API_TOKEN"))
  assert_true(is_secret_key("Api_Key"))
}

test "is_secret_key rejects non-secret keys" {
  assert_false(is_secret_key("name"))
  assert_false(is_secret_key("host"))
  assert_false(is_secret_key("port"))
  assert_false(is_secret_key("enabled"))
}
