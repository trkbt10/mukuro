///|
/// Dynamic plugin management interfaces

///|
/// Plugin change event type
pub(all) enum PluginChangeEvent {
  /// Plugin was added
  Added(String)
  /// Plugin was modified
  Modified(String)
  /// Plugin was removed
  Removed(String)
}

///|
/// Plugin state for dynamic management
pub(all) struct PluginState {
  /// Plugin ID
  id : String
  /// Whether the plugin is enabled
  enabled : Bool
  /// Whether the plugin should auto-start
  auto_start : Bool
  /// Current status
  status : PluginStatus
  /// Load timestamp
  loaded_at : Int64
  /// Last modified timestamp
  modified_at : Int64
}

///|
/// Default plugin state
pub fn PluginState::default(id~ : String) -> PluginState {
  {
    id,
    enabled: true,
    auto_start: true,
    status: PluginStatus::Stopped,
    loaded_at: 0L,
    modified_at: 0L,
  }
}

///|
/// Dynamic plugin manager trait
pub(open) trait DynamicPluginManager {
  /// Scan plugin directory for available plugins
  scan_plugins(Self) -> Array[String] raise

  /// Add a plugin from manifest path
  add_plugin(Self, manifest_path~ : String) -> Unit raise

  /// Remove a plugin by ID
  remove_plugin(Self, id~ : String) -> Unit raise

  /// Enable a plugin
  enable_plugin(Self, id~ : String) -> Unit raise

  /// Disable a plugin
  disable_plugin(Self, id~ : String) -> Unit raise

  /// Reload a plugin (stop, reload manifest, start)
  reload_plugin(Self, id~ : String) -> Unit raise

  /// Get plugin state
  get_plugin_state(Self, id~ : String) -> PluginState raise

  /// List all plugin states
  list_plugin_states(Self) -> Array[PluginState]

  /// Start watching for plugin changes
  start_watching(Self) -> Unit raise

  /// Stop watching for plugin changes
  stop_watching(Self) -> Unit
}

///|
/// Plugin watcher callback
pub(all) struct PluginWatcherCallback {
  /// Called when a plugin is added
  on_added : (String) -> Unit
  /// Called when a plugin is modified
  on_modified : (String) -> Unit
  /// Called when a plugin is removed
  on_removed : (String) -> Unit
}

///|
/// Default watcher callback (no-op)
pub fn PluginWatcherCallback::default() -> PluginWatcherCallback {
  { on_added: fn(_) {  }, on_modified: fn(_) {  }, on_removed: fn(_) {  } }
}

///|
/// Plugin watcher trait for file system monitoring
pub(open) trait PluginWatcher {
  /// Start watching a directory
  watch(Self, path~ : String, callback~ : PluginWatcherCallback) -> Unit raise

  /// Stop watching
  stop(Self) -> Unit

  /// Check if watching
  is_watching(Self) -> Bool
}

///|
/// Plugin manager error
pub(all) suberror PluginManagerError {
  /// Plugin not found
  NotFound(String)
  /// Plugin already exists
  AlreadyExists(String)
  /// Invalid plugin manifest
  InvalidManifest(String)
  /// Plugin is not enabled
  Disabled(String)
  /// Watch error
  WatchError(String)
  /// Filesystem error
  FilesystemError(String)
}
