///|
/// Stub main for non-native targets
/// This example is designed for native target only

// Reference @interfaces to avoid unused_package warning on non-native targets
fn _stub_use_interfaces() -> Unit {
  let _ : @interfaces.PluginType = @interfaces.PluginType::Tool
}

///|
fn main {
  // This plugin requires native target for stdin/stdout I/O
  // Build with: moon build --target native
}
