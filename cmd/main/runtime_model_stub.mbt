///|
/// RuntimeModelOrchestrator（JS/WASMスタブ）

///|
pub struct RuntimeModelOrchestrator {
  _placeholder : Unit
}

///|
struct TestToggle {
  mut forced_response : String?
}

///|
let test_toggle : TestToggle = { forced_response: None }

///|
pub fn RuntimeModelOrchestrator::default() -> RuntimeModelOrchestrator {
  { _placeholder: () }
}

///|
pub fn set_runtime_model_config_path_for_process(path : String) -> Unit {
  ignore(path)
}

///|
pub fn set_forced_response_for_test(response : String?) -> Unit {
  test_toggle.forced_response = response
}

///|
pub async fn runtime_model_invoke_async(
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  options : @types.ModelOptions,
) -> @types.ModelResponse {
  ignore(messages)
  ignore(tools)
  ignore(options)
  match test_toggle.forced_response {
    Some(content) => @types.ModelResponse::Text(content)
    None =>
      @types.ModelResponse::ModelError(
        "Runtime model is unavailable on JS/WASM target",
      )
  }
}

///|
pub impl @interfaces.ModelOrchestrator for RuntimeModelOrchestrator with call(
  self,
  messages~,
  tools~,
  options~,
) {
  ignore(self)
  ignore(tools)
  ignore(options)
  ignore(messages)
  match test_toggle.forced_response {
    Some(content) => @types.ModelResponse::Text(content)
    None =>
      @types.ModelResponse::ModelError(
        "Runtime model is unavailable on JS/WASM target",
      )
  }
}
