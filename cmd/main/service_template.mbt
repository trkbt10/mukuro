///|
/// Service Templates
/// Generate plist (macOS) and systemd unit (Linux) files

///|
/// Escape XML special characters for plist output
pub fn escape_xml(s : String) -> String {
  let mut result = ""
  let chars = s.to_array()
  for c in chars {
    match c {
      '&' => result = result + "&amp;"
      '<' => result = result + "&lt;"
      '>' => result = result + "&gt;"
      '"' => result = result + "&quot;"
      '\'' => result = result + "&#39;"
      _ => result = result + c.to_string()
    }
  }
  result
}

///|
/// Escape systemd unit file argument characters
pub fn escape_systemd_arg(s : String) -> String {
  let mut result = ""
  let chars = s.to_array()
  for c in chars {
    match c {
      '$' => result = result + "$$"
      '%' => result = result + "%%"
      '\\' => result = result + "\\\\"
      '"' => result = result + "\\\""
      _ => result = result + c.to_string()
    }
  }
  result
}

///|
/// Generate launchd plist content
pub fn generate_launchd_plist(config : ServiceConfig) -> String {
  let mut plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  plist = plist +
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
  plist = plist + "<plist version=\"1.0\">\n"
  plist = plist + "<dict>\n"
  // Label
  plist = plist + "  <key>Label</key>\n"
  plist = plist +
    "  <string>" +
    escape_xml(config.name) +
    "</string>\n"
  // Program arguments
  plist = plist + "  <key>ProgramArguments</key>\n"
  plist = plist + "  <array>\n"
  plist = plist +
    "    <string>" +
    escape_xml(config.executable) +
    "</string>\n"
  for arg in config.args {
    plist = plist + "    <string>" + escape_xml(arg) + "</string>\n"
  }
  match config.config_path {
    Some(path) => {
      plist = plist + "    <string>--config</string>\n"
      plist = plist +
        "    <string>" +
        escape_xml(path) +
        "</string>\n"
    }
    None => ()
  }
  plist = plist + "  </array>\n"
  // Working directory
  plist = plist + "  <key>WorkingDirectory</key>\n"
  plist = plist +
    "  <string>" +
    escape_xml(config.working_dir) +
    "</string>\n"
  // Run at load
  if config.auto_start {
    plist = plist + "  <key>RunAtLoad</key>\n"
    plist = plist + "  <true/>\n"
  }
  // Keep alive
  plist = plist + "  <key>KeepAlive</key>\n"
  plist = plist + "  <true/>\n"
  // Standard output
  match config.stdout_log {
    Some(path) => {
      plist = plist + "  <key>StandardOutPath</key>\n"
      plist = plist +
        "  <string>" +
        escape_xml(path) +
        "</string>\n"
    }
    None => ()
  }
  // Standard error
  match config.stderr_log {
    Some(path) => {
      plist = plist + "  <key>StandardErrorPath</key>\n"
      plist = plist +
        "  <string>" +
        escape_xml(path) +
        "</string>\n"
    }
    None => ()
  }
  // Throttle interval (prevent rapid restart)
  plist = plist + "  <key>ThrottleInterval</key>\n"
  plist = plist + "  <integer>30</integer>\n"
  plist = plist + "</dict>\n"
  plist = plist + "</plist>\n"
  plist
}

///|
/// Generate systemd unit content
pub fn generate_systemd_unit(config : ServiceConfig) -> String {
  let mut unit = "[Unit]\n"
  unit = unit +
    "Description=" +
    escape_systemd_arg(config.display_name) +
    "\n"
  unit = unit + "After=network.target\n"
  unit = unit + "\n"
  unit = unit + "[Service]\n"
  unit = unit + "Type=simple\n"
  // Exec start
  let mut exec_start = escape_systemd_arg(config.executable)
  for arg in config.args {
    exec_start = exec_start + " " + escape_systemd_arg(arg)
  }
  match config.config_path {
    Some(path) =>
      exec_start = exec_start + " --config " + escape_systemd_arg(path)
    None => ()
  }
  unit = unit + "ExecStart=" + exec_start + "\n"
  unit = unit +
    "WorkingDirectory=" +
    escape_systemd_arg(config.working_dir) +
    "\n"
  unit = unit + "Restart=always\n"
  unit = unit + "RestartSec=10\n"
  // Standard output
  match config.stdout_log {
    Some(path) =>
      unit = unit +
        "StandardOutput=append:" +
        escape_systemd_arg(path) +
        "\n"
    None => unit = unit + "StandardOutput=journal\n"
  }
  // Standard error
  match config.stderr_log {
    Some(path) =>
      unit = unit +
        "StandardError=append:" +
        escape_systemd_arg(path) +
        "\n"
    None => unit = unit + "StandardError=journal\n"
  }
  unit = unit + "\n"
  unit = unit + "[Install]\n"
  if config.auto_start {
    unit = unit + "WantedBy=default.target\n"
  }
  unit
}

///|
/// Get launchd plist path
pub fn get_launchd_plist_path(user_level : Bool) -> String {
  if user_level {
    // ~/Library/LaunchAgents/
    let home = get_home_dir()
    "\{home}/Library/LaunchAgents/\{service_name}.plist"
  } else {
    "/Library/LaunchDaemons/\{service_name}.plist"
  }
}

///|
/// Get systemd unit path
pub fn get_systemd_unit_path(user_level : Bool) -> String {
  if user_level {
    let home = get_home_dir()
    "\{home}/.config/systemd/user/mukuro-gateway.service"
  } else {
    "/etc/systemd/system/mukuro-gateway.service"
  }
}

///|
/// Get home directory (placeholder - needs FFI)
fn get_home_dir() -> String {
  // This would need to use FFI to get actual home dir
  // For now, return a placeholder
  "/Users/user"
}
