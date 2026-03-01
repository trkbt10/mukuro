///|
/// Native C FFI - コア定義
/// 型定義、変換ヘルパー、定数

// ============================================================
// 文字列型
// ============================================================

///|
/// C文字列型（null終端）
#external
pub type CString

// ============================================================
// 文字列変換ヘルパー
// ============================================================

///|
/// MoonBit String から CString への変換
/// NOTE: Pattern A (CString) は廃止予定。新規コードでは string_to_utf8_cstring を使用。
pub fn string_to_cstring(s : String) -> CString = "%identity"

///|
/// CString から MoonBit String への変換
pub fn cstring_to_string(cs : CString) -> String = "%identity"

///|
/// MoonBit String から UTF-8 null終端 Bytes への変換
/// C関数に渡すための適切なフォーマット（Pattern B - 推奨）
pub fn string_to_utf8_cstring(s : String) -> Bytes {
  @bytes.to_utf8_cstring(s)
}

// ============================================================
// アクセスモード定数 (access() 用)
// ============================================================

///|
/// F_OK (ファイル存在確認用)
pub let f_ok : Int = 0

///|
/// R_OK (読み取り権限確認用)
pub let r_ok : Int = 4

///|
/// W_OK (書き込み権限確認用)
pub let w_ok : Int = 2

///|
/// X_OK (実行権限確認用)
pub let x_ok : Int = 1
