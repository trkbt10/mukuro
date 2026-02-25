///|
/// Native plugin watcher implementation
/// Uses polling to detect plugin changes (manifest.json modifications)

///|
/// Plugin file info for change detection
struct PluginFileInfo {
  /// Plugin ID
  plugin_id : String
  /// Manifest path
  manifest_path : String
  /// Last modification time (simulated via content hash)
  mut content_hash : Int
}

///|
/// Native plugin watcher using polling
pub struct NativePluginWatcher {
  /// Plugin directory to watch
  plugin_dir : String
  /// Manifest filename
  manifest_filename : String
  /// Known plugins
  known_plugins : Map[String, PluginFileInfo]
  /// Callback for plugin events
  mut callback : @interfaces.PluginWatcherCallback?
  /// Whether watching is active
  mut is_watching : Bool
  /// Poll interval in milliseconds
  poll_interval_ms : Int
  /// File store for reading
  file_store : NativeFileStore
}

///|
/// Create a new native plugin watcher
pub fn NativePluginWatcher::new(
  plugin_dir~ : String,
  poll_interval_ms~ : Int,
) -> NativePluginWatcher {
  {
    plugin_dir,
    manifest_filename: "manifest.json",
    known_plugins: {},
    callback: None,
    is_watching: false,
    poll_interval_ms,
    file_store: NativeFileStore::new(base_dir=None),
  }
}

///|
/// Create with default poll interval (5 seconds)
pub fn NativePluginWatcher::default(
  plugin_dir~ : String,
) -> NativePluginWatcher {
  NativePluginWatcher::new(plugin_dir~, poll_interval_ms=5000)
}

///|
/// Simple hash function for content change detection
fn hash_string(s : String) -> Int {
  let mut hash = 0
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    hash = hash * 31 + chars[i].to_int()
    // Prevent overflow by masking
    hash = hash & 0x7FFFFFFF
  }
  hash
}

///|
/// Scan for plugins and detect changes
pub fn NativePluginWatcher::poll(self : NativePluginWatcher) -> Unit {
  // List directories in plugin_dir
  let dirs = @interfaces.FileStore::list_dir(
    self.file_store,
    path=self.plugin_dir,
  ) catch {
    _ => return
  }
  // Track current plugins
  let current_plugins : Map[String, Bool] = {}
  for dir in dirs {
    if dir.has_prefix(".") {
      continue
    }
    let manifest_path = "\{self.plugin_dir}/\{dir}/\{self.manifest_filename}"
    // Check if manifest exists
    let exists = @interfaces.FileStore::exists(
      self.file_store,
      path=manifest_path,
    ) catch {
      _ => false
    }
    if not(exists) {
      continue
    }
    current_plugins[dir] = true
    // Read manifest content for hash
    let content = self.file_store.read_text(manifest_path) catch {
      _ => continue
    }
    let content_hash = hash_string(content)
    match self.known_plugins.get(dir) {
      Some(info) =>
        // Check if modified
        if info.content_hash != content_hash {
          info.content_hash = content_hash
          // Fire modified event
          match self.callback {
            Some(cb) => (cb.on_modified)(dir)
            None => ()
          }
        }
      None => {
        // New plugin
        self.known_plugins[dir] = {
          plugin_id: dir,
          manifest_path,
          content_hash,
        }
        // Fire added event
        match self.callback {
          Some(cb) => (cb.on_added)(dir)
          None => ()
        }
      }
    }
  }
  // Check for removed plugins
  let to_remove : Array[String] = []
  for plugin_id, _ in self.known_plugins {
    if not(current_plugins.contains(plugin_id)) {
      to_remove.push(plugin_id)
    }
  }
  for plugin_id in to_remove {
    self.known_plugins.remove(plugin_id)
    // Fire removed event
    match self.callback {
      Some(cb) => (cb.on_removed)(plugin_id)
      None => ()
    }
  }
}

///|
/// Start watching (initial scan)
pub fn NativePluginWatcher::start(
  self : NativePluginWatcher,
  callback : @interfaces.PluginWatcherCallback,
) -> Unit {
  self.callback = Some(callback)
  self.is_watching = true
  // Do initial scan without firing events
  let dirs = @interfaces.FileStore::list_dir(
    self.file_store,
    path=self.plugin_dir,
  ) catch {
    _ => return
  }
  for dir in dirs {
    if dir.has_prefix(".") {
      continue
    }
    let manifest_path = "\{self.plugin_dir}/\{dir}/\{self.manifest_filename}"
    let exists = @interfaces.FileStore::exists(
      self.file_store,
      path=manifest_path,
    ) catch {
      _ => false
    }
    if not(exists) {
      continue
    }
    let content = self.file_store.read_text(manifest_path) catch {
      _ => continue
    }
    let content_hash = hash_string(content)
    self.known_plugins[dir] = { plugin_id: dir, manifest_path, content_hash }
  }
}

///|
/// Stop watching
pub fn NativePluginWatcher::stop(self : NativePluginWatcher) -> Unit {
  self.is_watching = false
  self.callback = None
}

///|
/// Check if watching
pub fn NativePluginWatcher::is_active(self : NativePluginWatcher) -> Bool {
  self.is_watching
}

///|
/// Get poll interval
pub fn NativePluginWatcher::get_poll_interval(
  self : NativePluginWatcher,
) -> Int {
  self.poll_interval_ms
}

///|
/// List known plugin IDs
pub fn NativePluginWatcher::list_known_plugins(
  self : NativePluginWatcher,
) -> Array[String] {
  self.known_plugins.keys().collect()
}

///|
/// Implementation of PluginWatcher trait
pub impl @interfaces.PluginWatcher for NativePluginWatcher with watch(
  self,
  path~,
  callback~,
) {
  // Update plugin_dir if different
  if path != self.plugin_dir {
    raise @interfaces.PluginManagerError::WatchError(
      "Cannot change watch path after creation",
    )
  }
  self.start(callback)
}

///|
pub impl @interfaces.PluginWatcher for NativePluginWatcher with stop(self) {
  NativePluginWatcher::stop(self)
}

///|
pub impl @interfaces.PluginWatcher for NativePluginWatcher with is_watching(
  self,
) {
  self.is_active()
}

///|
/// Async polling loop for continuous watching
pub async fn NativePluginWatcher::run_watch_loop(
  self : NativePluginWatcher,
) -> Unit {
  while self.is_watching {
    self.poll()
    @async.sleep(self.poll_interval_ms) catch {
      _ => break
    }
  }
}

///|
/// Plugin watcher factory
pub struct PluginWatcherFactory {}

///|
/// Create a new plugin watcher for the given directory
pub fn PluginWatcherFactory::create(plugin_dir : String) -> NativePluginWatcher {
  NativePluginWatcher::default(plugin_dir~)
}

///|
/// Create with custom poll interval
pub fn PluginWatcherFactory::create_with_interval(
  plugin_dir : String,
  poll_interval_ms : Int,
) -> NativePluginWatcher {
  NativePluginWatcher::new(plugin_dir~, poll_interval_ms~)
}
