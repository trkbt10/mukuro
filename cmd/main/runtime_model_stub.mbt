///|
/// RuntimeModelOrchestrator（JS/WASMスタブ）

///|
/// スタブ用 ProviderResolver（常に None を返す）
pub struct ConfigProviderResolver {
  _unit : Unit
}

///|
pub fn ConfigProviderResolver::new() -> ConfigProviderResolver {
  { _unit: () }
}

///|
pub impl @interfaces.ProviderResolver for ConfigProviderResolver with resolve(
  self,
) {
  ignore(self)
  None
}

///|
pub struct RuntimeModelOrchestrator {
  _placeholder : Unit
  provider_resolver : &@interfaces.ProviderResolver
}

///|
struct TestToggle {
  mut forced_response : String?
}

///|
let test_toggle : TestToggle = { forced_response: None }

///|
pub fn RuntimeModelOrchestrator::new(
  provider_resolver : &@interfaces.ProviderResolver,
) -> RuntimeModelOrchestrator {
  { _placeholder: (), provider_resolver }
}

///|
pub fn set_forced_response_for_test(response : String?) -> Unit {
  test_toggle.forced_response = response
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
