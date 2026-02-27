///|
/// 認証器実装

///|
/// シンプルなトークン認証器
/// 単一の固定トークンで認証を行う
pub struct SimpleTokenAuthenticator {
  /// 有効なトークン
  valid_token : String
  /// 発行済みトークン（revoke用）
  revoked_tokens : Array[String]
}

///|
/// SimpleTokenAuthenticatorを新規作成
pub fn SimpleTokenAuthenticator::new(
  token~ : String,
) -> SimpleTokenAuthenticator {
  { valid_token: token, revoked_tokens: [] }
}

///|
/// Authenticator実装
pub impl @interfaces.Authenticator for SimpleTokenAuthenticator with validate(
  self,
  token~,
) {
  // 無効化済みトークンのチェック
  for revoked in self.revoked_tokens {
    if @interfaces.constant_time_compare(token, revoked) {
      return @interfaces.AuthResult::Denied("Token has been revoked")
    }
  }
  // トークンの検証
  if @interfaces.constant_time_compare(token, self.valid_token) {
    @interfaces.AuthResult::Authenticated(
      @interfaces.AuthContext::token_only(token),
    )
  } else {
    @interfaces.AuthResult::Denied("Invalid token")
  }
}

///|
pub impl @interfaces.Authenticator for SimpleTokenAuthenticator with issue_token(
  self,
  user_id~,
) {
  // シンプル実装では新規トークン発行はサポートしない
  // 固定トークンを返す
  ignore(user_id)
  self.valid_token
}

///|
pub impl @interfaces.Authenticator for SimpleTokenAuthenticator with revoke(
  self,
  token~,
) {
  // トークンを無効化リストに追加
  self.revoked_tokens.push(token)
}

///|
/// 認証不要の認証器（開発用）
pub struct NoAuthAuthenticator {
  _placeholder : Unit
}

///|
/// NoAuthAuthenticatorを新規作成
pub fn NoAuthAuthenticator::new() -> NoAuthAuthenticator {
  { _placeholder: () }
}

///|
/// Authenticator実装（常に成功）
pub impl @interfaces.Authenticator for NoAuthAuthenticator with validate(
  _self,
  token~,
) {
  @interfaces.AuthResult::Authenticated(
    @interfaces.AuthContext::token_only(token),
  )
}

///|
pub impl @interfaces.Authenticator for NoAuthAuthenticator with issue_token(
  _self,
  user_id~,
) {
  "no-auth-token-\{user_id}"
}

///|
pub impl @interfaces.Authenticator for NoAuthAuthenticator with revoke(
  _self,
  token~,
) {
  ignore(token)
}
