///|
/// Runtime capability check（JS/WASM）

///|
pub fn runtime_model_unavailable_reason_impl() -> String? {
  Some(
    "Gateway runtime model on JS/WASM is not supported yet. Please use native target:\n  moon build cmd/main --target native\n  _build/native/debug/build/cmd/main/main.exe gateway start",
  )
}
