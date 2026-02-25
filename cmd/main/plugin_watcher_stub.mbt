///|
/// Plugin watcher stubs for non-native targets
/// Plugin watching is only supported on native target

///|
/// Setup plugin watcher (stub - no-op on non-native targets)
pub fn setup_plugin_watcher(_plugin_dir : String) -> Unit raise {
  // Plugin watching not supported on this target
}

///|
/// Start plugin watching (stub - no-op on non-native targets)
pub fn start_plugin_watching() -> Unit raise {
  // Plugin watching not supported on this target
}

///|
/// Stop plugin watching (stub - no-op on non-native targets)
pub fn stop_plugin_watching() -> Unit {
  // Plugin watching not supported on this target
}

///|
/// Poll for plugin changes (stub - no-op on non-native targets)
pub fn poll_plugin_changes() -> Unit {
  // Plugin watching not supported on this target
}
