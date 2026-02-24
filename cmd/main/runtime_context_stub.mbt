///|
/// Workspace由来コンテキスト注入（JS/WASMスタブ）

///|
pub fn set_workspace_context_dir_for_process(path : String) -> Unit {
  ignore(path)
}

///|
pub fn enrich_envelope_with_workspace_context_impl(
  envelope : @types.InboundEnvelope,
) -> @types.InboundEnvelope {
  envelope
}
