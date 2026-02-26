///|
/// Dynamic plugin manager implementation

///|
/// Dynamic plugin manager
pub struct DynamicPluginManagerImpl {
  /// Plugin host
  host : PluginHostImpl
  /// Plugin states (id -> state)
  states : Map[String, @interfaces.PluginState]
  /// Plugin directory
  plugin_dir : String
  /// Manifest filename
  manifest_filename : String
  /// Watcher callback
  mut watcher_callback : @interfaces.PluginWatcherCallback?
  /// Whether watching is active
  mut is_watching : Bool
  /// Filesystem operations (for testability)
  list_dir : ((String) -> Array[String] raise)?
  read_file : ((String) -> String raise)?
  file_exists : ((String) -> Bool)?
}

///|
/// Create a new dynamic plugin manager
pub fn DynamicPluginManagerImpl::new(
  host~ : PluginHostImpl,
  plugin_dir~ : String,
) -> DynamicPluginManagerImpl {
  {
    host,
    states: {},
    plugin_dir,
    manifest_filename: "manifest.json",
    watcher_callback: None,
    is_watching: false,
    list_dir: None,
    read_file: None,
    file_exists: None,
  }
}

///|
/// Create with filesystem callbacks
pub fn DynamicPluginManagerImpl::with_fs(
  host~ : PluginHostImpl,
  plugin_dir~ : String,
  list_dir~ : (String) -> Array[String] raise,
  read_file~ : (String) -> String raise,
  file_exists~ : (String) -> Bool,
) -> DynamicPluginManagerImpl {
  {
    host,
    states: {},
    plugin_dir,
    manifest_filename: "manifest.json",
    watcher_callback: None,
    is_watching: false,
    list_dir: Some(list_dir),
    read_file: Some(read_file),
    file_exists: Some(file_exists),
  }
}

///|
/// Scan plugin directory
pub fn DynamicPluginManagerImpl::scan(
  self : DynamicPluginManagerImpl,
) -> Array[String] raise {
  match self.list_dir {
    Some(list_fn) => {
      let dirs = list_fn(self.plugin_dir)
      let plugins : Array[String] = []
      for dir in dirs {
        if not(dir.has_prefix(".")) {
          // Check if manifest exists
          let manifest_path = "\{self.plugin_dir}/\{dir}/\{self.manifest_filename}"
          match self.file_exists {
            Some(exists_fn) => if exists_fn(manifest_path) { plugins.push(dir) }
            None => plugins.push(dir)
          }
        }
      }
      plugins
    }
    None => []
  }
}

///|
/// Load a plugin from manifest path
pub fn DynamicPluginManagerImpl::load_plugin(
  self : DynamicPluginManagerImpl,
  manifest_path : String,
) -> Unit raise {
  match self.read_file {
    Some(read_fn) => {
      let content = read_fn(manifest_path)
      let json = @json.parse(content) catch {
        e =>
          raise @interfaces.PluginManagerError::InvalidManifest(
            "JSON parse error: \{e}",
          )
      }
      match parse_manifest(json) {
        Some(manifest) => {
          // Register with host
          self.host.register_plugin(manifest)
          // Create state
          let state : @interfaces.PluginState = {
            id: manifest.id,
            enabled: true,
            auto_start: true,
            status: @interfaces.PluginStatus::Stopped,
            loaded_at: 0L,
            modified_at: 0L,
          }
          self.states[manifest.id] = state
        }
        None =>
          raise @interfaces.PluginManagerError::InvalidManifest(manifest_path)
      }
    }
    None =>
      raise @interfaces.PluginManagerError::FilesystemError(
        "No read_file function configured",
      )
  }
}

///|
/// Enable a plugin
pub fn DynamicPluginManagerImpl::enable(
  self : DynamicPluginManagerImpl,
  id : String,
) -> Unit raise {
  match self.states.get(id) {
    Some(state) => {
      let new_state : @interfaces.PluginState = {
        id: state.id,
        enabled: true,
        auto_start: state.auto_start,
        status: state.status,
        loaded_at: state.loaded_at,
        modified_at: state.modified_at,
      }
      self.states[id] = new_state
    }
    None => raise @interfaces.PluginManagerError::NotFound(id)
  }
}

///|
/// Disable a plugin
pub async fn DynamicPluginManagerImpl::disable(
  self : DynamicPluginManagerImpl,
  id : String,
) -> Unit {
  match self.states.get(id) {
    Some(state) => {
      // Stop if running
      match state.status {
        @interfaces.PluginStatus::Running =>
          @interfaces.PluginHost::stop_plugin(self.host, id~) catch {
            _ => ()
          }
        _ => ()
      }
      let new_state : @interfaces.PluginState = {
        id: state.id,
        enabled: false,
        auto_start: state.auto_start,
        status: @interfaces.PluginStatus::Stopped,
        loaded_at: state.loaded_at,
        modified_at: state.modified_at,
      }
      self.states[id] = new_state
    }
    None => raise @interfaces.PluginManagerError::NotFound(id)
  }
}

///|
/// Reload a plugin
pub async fn DynamicPluginManagerImpl::reload(
  self : DynamicPluginManagerImpl,
  id : String,
) -> Unit {
  match self.states.get(id) {
    Some(state) => {
      // Stop if running
      let was_running = match state.status {
        @interfaces.PluginStatus::Running => {
          @interfaces.PluginHost::stop_plugin(self.host, id~) catch {
            _ => ()
          }
          true
        }
        _ => false
      }
      // Find and reload manifest
      match self.host.registry.get(id) {
        Some(instance) => {
          // Re-read manifest from file
          let plugin_path = "\{self.plugin_dir}/\{id}"
          let manifest_path = "\{plugin_path}/\{self.manifest_filename}"
          match self.read_file {
            Some(read_fn) => {
              let content = read_fn(manifest_path)
              let json = @json.parse(content) catch {
                e =>
                  raise @interfaces.PluginManagerError::InvalidManifest(
                    "JSON parse error: \{e}",
                  )
              }
              match parse_manifest(json) {
                Some(manifest) => {
                  // Unregister and re-register
                  self.host.registry.unregister(id)
                  self.host.register_plugin(manifest)
                }
                None =>
                  raise @interfaces.PluginManagerError::InvalidManifest(
                    manifest_path,
                  )
              }
            }
            None => ignore(instance)
          }
        }
        None => ()
      }
      // Restart if was running and still enabled
      if was_running && state.enabled {
        @interfaces.PluginHost::start_plugin(self.host, id~) catch {
          _ => ()
        }
      }
    }
    None => raise @interfaces.PluginManagerError::NotFound(id)
  }
}

///|
/// Remove a plugin
pub async fn DynamicPluginManagerImpl::remove(
  self : DynamicPluginManagerImpl,
  id : String,
) -> Unit {
  match self.states.get(id) {
    Some(state) => {
      // Stop if running
      match state.status {
        @interfaces.PluginStatus::Running =>
          @interfaces.PluginHost::stop_plugin(self.host, id~) catch {
            _ => ()
          }
        _ => ()
      }
      // Unregister
      self.host.registry.unregister(id)
      // Remove state
      self.states.remove(id)
    }
    None => raise @interfaces.PluginManagerError::NotFound(id)
  }
}

///|
/// Get plugin state
pub fn DynamicPluginManagerImpl::get_state(
  self : DynamicPluginManagerImpl,
  id : String,
) -> @interfaces.PluginState raise {
  match self.states.get(id) {
    Some(state) => state
    None => raise @interfaces.PluginManagerError::NotFound(id)
  }
}

///|
/// List all plugin states
pub fn DynamicPluginManagerImpl::list_states(
  self : DynamicPluginManagerImpl,
) -> Array[@interfaces.PluginState] {
  let states : Array[@interfaces.PluginState] = []
  for state in self.states.values() {
    states.push(state)
  }
  states
}

///|
/// Start watching for changes
pub fn DynamicPluginManagerImpl::start_watching(
  self : DynamicPluginManagerImpl,
  callback : @interfaces.PluginWatcherCallback,
) -> Unit {
  self.watcher_callback = Some(callback)
  self.is_watching = true
}

///|
/// Stop watching
pub fn DynamicPluginManagerImpl::stop_watching(
  self : DynamicPluginManagerImpl,
) -> Unit {
  self.is_watching = false
  self.watcher_callback = None
}

///|
/// Handle plugin added event
pub async fn DynamicPluginManagerImpl::handle_plugin_added(
  self : DynamicPluginManagerImpl,
  plugin_id : String,
) -> Unit {
  let manifest_path = "\{self.plugin_dir}/\{plugin_id}/\{self.manifest_filename}"
  self.load_plugin(manifest_path) catch {
    _ => ()
  }
  match self.watcher_callback {
    Some(callback) => (callback.on_added)(plugin_id)
    None => ()
  }
}

///|
/// Handle plugin modified event
pub async fn DynamicPluginManagerImpl::handle_plugin_modified(
  self : DynamicPluginManagerImpl,
  plugin_id : String,
) -> Unit {
  self.reload(plugin_id) catch {
    _ => ()
  }
  match self.watcher_callback {
    Some(callback) => (callback.on_modified)(plugin_id)
    None => ()
  }
}

///|
/// Handle plugin removed event
pub async fn DynamicPluginManagerImpl::handle_plugin_removed(
  self : DynamicPluginManagerImpl,
  plugin_id : String,
) -> Unit {
  self.remove(plugin_id) catch {
    _ => ()
  }
  match self.watcher_callback {
    Some(callback) => (callback.on_removed)(plugin_id)
    None => ()
  }
}

///|
/// Implementation of DynamicPluginManager trait
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with scan_plugins(
  self,
) {
  self.scan()
}

///|
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with add_plugin(
  self,
  manifest_path~,
) {
  self.load_plugin(manifest_path)
}

///|
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with remove_plugin(
  self,
  id~,
) {
  self.remove(id)
}

///|
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with enable_plugin(
  self,
  id~,
) {
  self.enable(id)
}

///|
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with disable_plugin(
  self,
  id~,
) {
  self.disable(id)
}

///|
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with reload_plugin(
  self,
  id~,
) {
  self.reload(id)
}

///|
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with get_plugin_state(
  self,
  id~,
) {
  self.get_state(id)
}

///|
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with list_plugin_states(
  self,
) {
  self.list_states()
}

///|
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with start_watching(
  self,
) {
  self.start_watching(@interfaces.PluginWatcherCallback::default())
}

///|
pub impl @interfaces.DynamicPluginManager for DynamicPluginManagerImpl with stop_watching(
  self,
) {
  DynamicPluginManagerImpl::stop_watching(self)
}
