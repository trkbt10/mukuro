///|
/// Native plugin watcher integration
/// Connects NativePluginWatcher to the plugin system

///|
/// Global plugin watcher instance
let global_plugin_watcher : Ref[@plugin_runtime.NativePluginWatcher?] = { val: None }

///|
/// Setup plugin watcher for the plugin system
pub fn setup_plugin_watcher(plugin_dir : String) -> Unit raise {
  match global_plugin_initializer.val {
    Some(initializer) => {
      let watcher = @plugin_runtime.NativePluginWatcher::default(plugin_dir~)
      initializer.set_watcher(watcher)
      global_plugin_watcher.val = Some(watcher)
    }
    None =>
      raise @interfaces.PluginError::InvalidManifest(
        "Plugin system not initialized",
      )
  }
}

///|
/// Start plugin watching
pub fn start_plugin_watching() -> Unit raise {
  match global_plugin_initializer.val {
    Some(initializer) => initializer.start_watching()
    None =>
      raise @interfaces.PluginError::InvalidManifest(
        "Plugin system not initialized",
      )
  }
}

///|
/// Stop plugin watching
pub fn stop_plugin_watching() -> Unit {
  match global_plugin_initializer.val {
    Some(initializer) => initializer.stop_watching()
    None => ()
  }
}

///|
/// Poll for plugin changes (call periodically)
pub fn poll_plugin_changes() -> Unit {
  match global_plugin_watcher.val {
    Some(watcher) => watcher.poll()
    None => ()
  }
}

///|
/// Run async plugin watch loop
pub async fn run_plugin_watch_loop() -> Unit {
  match global_plugin_watcher.val {
    Some(watcher) => watcher.run_watch_loop()
    None => ()
  }
}
