///|
/// Plugin transport stubs for non-native targets

///|
/// Setup native transport handlers (stub - uses default transport)
pub fn setup_native_transport_handlers() -> Unit {
  // Native transport not available on this target
}

///|
/// Initialize plugin system with native transport (stub - uses default) (async)
pub async fn initialize_plugin_system_with_native_transport() -> Unit {
  // Just use regular initialization on non-native targets
  initialize_plugin_system()
}
