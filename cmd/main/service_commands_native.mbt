///|
/// Service Commands (Native)
/// Platform-specific service management implementation

///|
/// Execute service command
pub fn execute_service_command(cmd : ServiceCommand) -> CliResult {
  match cmd {
    ServiceCommand::Install(opts) => execute_service_install(opts)
    ServiceCommand::Uninstall => execute_service_uninstall()
    ServiceCommand::Start => execute_service_start()
    ServiceCommand::Stop => execute_service_stop()
    ServiceCommand::Restart => execute_service_restart()
    ServiceCommand::Status(opts) => execute_service_status(opts)
    ServiceCommand::Logs(opts) => execute_service_logs(opts)
    ServiceCommand::Unknown(subcmd) =>
      CliResult::Error("Unknown service command: \{subcmd}")
  }
}

///|
/// Install service
fn execute_service_install(opts : ServiceInstallOptions) -> CliResult {
  // Get executable path
  let exe_path = @native.cstring_to_string(@native.c_get_exe_path())
  if exe_path.length() == 0 {
    return CliResult::Error("Failed to get executable path")
  }
  // Create service config
  let config = ServiceConfig::default(exe_path, opts.config_path)
  let config = { ..config, user_level: opts.user, auto_start: opts.auto_start }
  // Detect platform and install
  let platform = detect_platform_native()
  match platform {
    ServicePlatform::MacOS => install_launchd_service(config)
    ServicePlatform::Linux => install_systemd_service(config)
    _ => CliResult::Error("Service installation not supported on this platform")
  }
}

///|
/// Detect platform using native checks
fn detect_platform_native() -> ServicePlatform {
  // Check for macOS by testing for /Library
  let macos_check = @native.c_access_bytes(
    @native.string_to_utf8_cstring("/Library"),
    @native.f_ok,
  )
  if macos_check == 0 {
    return ServicePlatform::MacOS
  }
  // Check for Linux by testing for /etc/systemd
  let linux_check = @native.c_access_bytes(
    @native.string_to_utf8_cstring("/etc/systemd"),
    @native.f_ok,
  )
  if linux_check == 0 {
    return ServicePlatform::Linux
  }
  ServicePlatform::Unknown
}

///|
/// Install launchd service (macOS)
fn install_launchd_service(config : ServiceConfig) -> CliResult {
  let plist_content = generate_launchd_plist(config)
  let plist_path = get_launchd_plist_path(config.user_level)
  // Write plist file
  let result = @native.c_write_text_file_bytes(
    @native.string_to_utf8_cstring(plist_path),
    @native.string_to_utf8_cstring(plist_content),
  )
  if result != 0 {
    return CliResult::Error("Failed to write plist file: \{plist_path}")
  }
  // Load the service
  let load_cmd = "launchctl load \{plist_path}"
  let load_result = @native.c_system_bytes(
    @native.string_to_utf8_cstring(load_cmd),
  )
  if load_result != 0 {
    return CliResult::Error(
      "Failed to load service. Run: launchctl load \{plist_path}",
    )
  }
  CliResult::Ok("Service installed successfully at \{plist_path}")
}

///|
/// Install systemd service (Linux)
fn install_systemd_service(config : ServiceConfig) -> CliResult {
  let unit_content = generate_systemd_unit(config)
  let unit_path = get_systemd_unit_path(config.user_level)
  // Write unit file
  let result = @native.c_write_text_file_bytes(
    @native.string_to_utf8_cstring(unit_path),
    @native.string_to_utf8_cstring(unit_content),
  )
  if result != 0 {
    return CliResult::Error("Failed to write unit file: \{unit_path}")
  }
  // Reload systemd
  let reload_cmd = if config.user_level {
    "systemctl --user daemon-reload"
  } else {
    "systemctl daemon-reload"
  }
  ignore(@native.c_system_bytes(@native.string_to_utf8_cstring(reload_cmd)))
  // Enable service
  let enable_cmd = if config.user_level {
    "systemctl --user enable mukuro-gateway"
  } else {
    "systemctl enable mukuro-gateway"
  }
  if config.auto_start {
    ignore(@native.c_system_bytes(@native.string_to_utf8_cstring(enable_cmd)))
  }
  CliResult::Ok("Service installed successfully at \{unit_path}")
}

///|
/// Uninstall service
fn execute_service_uninstall() -> CliResult {
  let platform = detect_platform_native()
  match platform {
    ServicePlatform::MacOS => uninstall_launchd_service()
    ServicePlatform::Linux => uninstall_systemd_service()
    _ =>
      CliResult::Error("Service uninstallation not supported on this platform")
  }
}

///|
/// Uninstall launchd service
fn uninstall_launchd_service() -> CliResult {
  // Try user-level first
  let user_plist = get_launchd_plist_path(true)
  let user_exists = @native.c_file_exists_bytes(
    @native.string_to_utf8_cstring(user_plist),
  )
  if user_exists == 1 {
    let unload_cmd = "launchctl unload \{user_plist}"
    ignore(@native.c_system_bytes(@native.string_to_utf8_cstring(unload_cmd)))
    ignore(
      @native.c_remove_file_bytes(@native.string_to_utf8_cstring(user_plist)),
    )
    return CliResult::Ok("Service uninstalled from \{user_plist}")
  }
  // Try system-level
  let sys_plist = get_launchd_plist_path(false)
  let sys_exists = @native.c_file_exists_bytes(
    @native.string_to_utf8_cstring(sys_plist),
  )
  if sys_exists == 1 {
    let unload_cmd = "launchctl unload \{sys_plist}"
    ignore(@native.c_system_bytes(@native.string_to_utf8_cstring(unload_cmd)))
    ignore(
      @native.c_remove_file_bytes(@native.string_to_utf8_cstring(sys_plist)),
    )
    return CliResult::Ok("Service uninstalled from \{sys_plist}")
  }
  CliResult::Error("Service not found")
}

///|
/// Uninstall systemd service
fn uninstall_systemd_service() -> CliResult {
  // Try user-level first
  let user_unit = get_systemd_unit_path(true)
  let user_exists = @native.c_file_exists_bytes(
    @native.string_to_utf8_cstring(user_unit),
  )
  if user_exists == 1 {
    ignore(
      @native.c_system_bytes(
        @native.string_to_utf8_cstring("systemctl --user stop mukuro-gateway"),
      ),
    )
    ignore(
      @native.c_system_bytes(
        @native.string_to_utf8_cstring(
          "systemctl --user disable mukuro-gateway",
        ),
      ),
    )
    ignore(
      @native.c_remove_file_bytes(@native.string_to_utf8_cstring(user_unit)),
    )
    ignore(
      @native.c_system_bytes(
        @native.string_to_utf8_cstring("systemctl --user daemon-reload"),
      ),
    )
    return CliResult::Ok("Service uninstalled from \{user_unit}")
  }
  // Try system-level
  let sys_unit = get_systemd_unit_path(false)
  let sys_exists = @native.c_file_exists_bytes(
    @native.string_to_utf8_cstring(sys_unit),
  )
  if sys_exists == 1 {
    ignore(
      @native.c_system_bytes(
        @native.string_to_utf8_cstring("systemctl stop mukuro-gateway"),
      ),
    )
    ignore(
      @native.c_system_bytes(
        @native.string_to_utf8_cstring("systemctl disable mukuro-gateway"),
      ),
    )
    ignore(
      @native.c_remove_file_bytes(@native.string_to_utf8_cstring(sys_unit)),
    )
    ignore(
      @native.c_system_bytes(
        @native.string_to_utf8_cstring("systemctl daemon-reload"),
      ),
    )
    return CliResult::Ok("Service uninstalled from \{sys_unit}")
  }
  CliResult::Error("Service not found")
}

///|
/// Start service
fn execute_service_start() -> CliResult {
  let platform = detect_platform_native()
  match platform {
    ServicePlatform::MacOS => {
      let cmd = "launchctl start \{service_name}"
      let result = @native.c_system_bytes(@native.string_to_utf8_cstring(cmd))
      if result == 0 {
        CliResult::Ok("Service started")
      } else {
        CliResult::Error("Failed to start service")
      }
    }
    ServicePlatform::Linux => {
      // Try user-level first
      let user_unit = get_systemd_unit_path(true)
      let user_exists = @native.c_file_exists_bytes(
        @native.string_to_utf8_cstring(user_unit),
      )
      if user_exists == 1 {
        let result = @native.c_system_bytes(
          @native.string_to_utf8_cstring(
            "systemctl --user start mukuro-gateway",
          ),
        )
        if result == 0 {
          return CliResult::Ok("Service started (user)")
        }
      }
      let result = @native.c_system_bytes(
        @native.string_to_utf8_cstring("systemctl start mukuro-gateway"),
      )
      if result == 0 {
        CliResult::Ok("Service started (system)")
      } else {
        CliResult::Error("Failed to start service")
      }
    }
    _ => CliResult::Error("Service control not supported on this platform")
  }
}

///|
/// Stop service
fn execute_service_stop() -> CliResult {
  let platform = detect_platform_native()
  match platform {
    ServicePlatform::MacOS => {
      let cmd = "launchctl stop \{service_name}"
      let result = @native.c_system_bytes(@native.string_to_utf8_cstring(cmd))
      if result == 0 {
        CliResult::Ok("Service stopped")
      } else {
        CliResult::Error("Failed to stop service")
      }
    }
    ServicePlatform::Linux => {
      // Try user-level first
      let user_unit = get_systemd_unit_path(true)
      let user_exists = @native.c_file_exists_bytes(
        @native.string_to_utf8_cstring(user_unit),
      )
      if user_exists == 1 {
        let result = @native.c_system_bytes(
          @native.string_to_utf8_cstring("systemctl --user stop mukuro-gateway"),
        )
        if result == 0 {
          return CliResult::Ok("Service stopped (user)")
        }
      }
      let result = @native.c_system_bytes(
        @native.string_to_utf8_cstring("systemctl stop mukuro-gateway"),
      )
      if result == 0 {
        CliResult::Ok("Service stopped (system)")
      } else {
        CliResult::Error("Failed to stop service")
      }
    }
    _ => CliResult::Error("Service control not supported on this platform")
  }
}

///|
/// Restart service
fn execute_service_restart() -> CliResult {
  match execute_service_stop() {
    CliResult::Error(_) => ()
    _ => ()
  }
  // Small delay
  @native.c_sleep_ms(500)
  execute_service_start()
}

///|
/// Get service status
fn execute_service_status(opts : ServiceStatusOptions) -> CliResult {
  let status = get_service_status()
  if opts.json {
    CliResult::Ok(status.to_json().stringify())
  } else {
    let mut msg = "Installed: \{status.installed}\n"
    msg = msg + "Running: \{status.running}\n"
    match status.pid {
      Some(p) => msg = msg + "PID: \{p}\n"
      None => ()
    }
    msg = msg + "Message: \{status.message}"
    CliResult::Ok(msg)
  }
}

///|
/// Get service status details
fn get_service_status() -> ServiceStatus {
  let platform = detect_platform_native()
  match platform {
    ServicePlatform::MacOS => get_launchd_status()
    ServicePlatform::Linux => get_systemd_status()
    _ =>
      {
        installed: false,
        running: false,
        pid: None,
        message: "Unsupported platform",
      }
  }
}

///|
/// Get launchd service status
fn get_launchd_status() -> ServiceStatus {
  let user_plist = get_launchd_plist_path(true)
  let sys_plist = get_launchd_plist_path(false)
  let user_exists = @native.c_file_exists_bytes(
    @native.string_to_utf8_cstring(user_plist),
  )
  let sys_exists = @native.c_file_exists_bytes(
    @native.string_to_utf8_cstring(sys_plist),
  )
  if user_exists != 1 && sys_exists != 1 {
    return {
      installed: false,
      running: false,
      pid: None,
      message: "Not installed",
    }
  }
  // Service is installed, check if running via launchctl list
  // This is simplified - would need proper parsing of launchctl output
  let plist_path = if user_exists == 1 { user_plist } else { sys_plist }
  {
    installed: true,
    running: false,
    pid: None,
    message: "Installed at \{plist_path}",
  }
}

///|
/// Get systemd service status
fn get_systemd_status() -> ServiceStatus {
  let user_unit = get_systemd_unit_path(true)
  let sys_unit = get_systemd_unit_path(false)
  let user_exists = @native.c_file_exists_bytes(
    @native.string_to_utf8_cstring(user_unit),
  )
  let sys_exists = @native.c_file_exists_bytes(
    @native.string_to_utf8_cstring(sys_unit),
  )
  if user_exists != 1 && sys_exists != 1 {
    return {
      installed: false,
      running: false,
      pid: None,
      message: "Not installed",
    }
  }
  let path = if user_exists == 1 { user_unit } else { sys_unit }
  {
    installed: true,
    running: false,
    pid: None,
    message: "Installed at \{path}",
  }
}

///|
/// View service logs
fn execute_service_logs(opts : ServiceLogsOptions) -> CliResult {
  let platform = detect_platform_native()
  match platform {
    ServicePlatform::MacOS => {
      // macOS logs are typically in ~/Library/Logs/ or system log
      let cmd = if opts.follow {
        "log stream --predicate 'subsystem == \"com.mukuro.gateway\"' --level info"
      } else {
        "log show --predicate 'subsystem == \"com.mukuro.gateway\"' --last \{opts.lines}m"
      }
      ignore(@native.c_system_bytes(@native.string_to_utf8_cstring(cmd)))
      CliResult::Ok("")
    }
    ServicePlatform::Linux => {
      let user_unit = get_systemd_unit_path(true)
      let user_exists = @native.c_file_exists_bytes(
        @native.string_to_utf8_cstring(user_unit),
      )
      let base_cmd = if user_exists == 1 {
        "journalctl --user -u mukuro-gateway"
      } else {
        "journalctl -u mukuro-gateway"
      }
      let cmd = if opts.follow {
        "\{base_cmd} -f -n \{opts.lines}"
      } else {
        "\{base_cmd} -n \{opts.lines}"
      }
      ignore(@native.c_system_bytes(@native.string_to_utf8_cstring(cmd)))
      CliResult::Ok("")
    }
    _ => CliResult::Error("Log viewing not supported on this platform")
  }
}
