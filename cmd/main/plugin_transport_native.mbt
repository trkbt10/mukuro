///|
/// Native plugin transport integration
/// Uses native transport factory for actual plugin communication

///|
/// Setup native transport handlers for all loaded plugins
pub fn setup_native_transport_handlers() -> Unit {
  match global_plugin_initializer.val {
    Some(initializer) => {
      let host = initializer.get_host()
      let factory = @native.get_native_transport_factory()
      // Replace transport handlers for all registered plugins
      for manifest in @interfaces.PluginHost::list_plugins(host) {
        let handler = factory.create_handler(manifest) catch { _ => continue }
        host.set_transport_handler(manifest.id, handler)
      }
    }
    None => ()
  }
}

///|
/// Initialize plugin system with native transport
pub fn initialize_plugin_system_with_native_transport() -> Unit raise {
  // First initialize normally
  initialize_plugin_system()
  // Then setup native transport handlers
  setup_native_transport_handlers()
}
