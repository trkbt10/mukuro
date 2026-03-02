///|
/// Onboard API stub (non-native targets)

///|
async fn try_onboard_generate(_body : String) -> ControlApiResponse {
  json_response(501, {
    "error": "not_implemented",
    "message": "Onboard API not available",
  })
}
