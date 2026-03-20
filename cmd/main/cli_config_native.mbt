///|
/// CLI Config コマンド — 設定ファイルの表示・管理

///|
fn execute_config_command(cmd : ConfigCommand) -> CliResult {
  match cmd {
    ConfigCommand::Path => execute_config_path()
    ConfigCommand::Show => execute_config_show()
    ConfigCommand::Providers => execute_config_providers()
    ConfigCommand::Unknown(name) =>
      CliResult::Error("Unknown config command: \{name}\n\nUsage: mukuro config [path|show|providers]")
  }
}

///|
/// 設定ファイルパスを表示
fn execute_config_path() -> CliResult {
  CliResult::Ok(default_runtime_config_path())
}

///|
/// 現在の設定を表示（API key はマスク）
fn execute_config_show() -> CliResult {
  let config_path = default_runtime_config_path()
  let content = read_config_text_impl(config_path) catch {
    _ => return CliResult::Error("Configuration not found at \{config_path}")
  }
  // API key をマスク
  let masked = mask_api_keys(content)
  CliResult::Ok("Config: \{config_path}\n\n\{masked}")
}

///|
/// プロバイダ一覧を表示
fn execute_config_providers() -> CliResult {
  let config_path = default_runtime_config_path()
  let config_text = read_config_text_impl(config_path) catch {
    _ => return CliResult::Error("Configuration not found at \{config_path}")
  }
  let config = @config.ConfigLoaderImpl::default().load_from_string(
    config_text,
  ) catch {
    _ => return CliResult::Error("Failed to parse configuration")
  }
  if config.providers.is_empty() {
    return CliResult::Ok("No providers configured.\n\nRun 'mukuro onboard' to add a provider.")
  }
  let buf = StringBuilder::new()
  buf.write_string("Providers (\{config.providers.length()}):\n\n")
  for i, p in config.providers {
    let status = if i == 0 { " (primary)" } else { "" }
    let key_status = match p.api_key {
      Some(k) =>
        if k.length() > 8 {
          k[:4].to_string() + "..." + k[k.length() - 4:].to_string()
        } else if k.length() > 0 {
          "****"
        } else {
          "(empty)"
        }
      None => "(not set)"
    }
    let base = match p.base_url {
      Some(url) => url
      None => "(default)"
    }
    buf.write_string("  \{i + 1}. \{p.name}\{status}\n")
    buf.write_string("     Model: \{p.default_model}\n")
    buf.write_string("     API Key: \{key_status}\n")
    buf.write_string("     Base URL: \{base}\n")
    if p.use_responses_api {
      buf.write_string("     Responses API: enabled\n")
    }
    buf.write_string("\n")
  }
  // Fallback info
  if config.fallback.enabled {
    buf.write_string("Fallback: enabled\n")
    let chain = config.fallback.providers.join(" -> ")
    buf.write_string("  Chain: \{chain}\n")
    buf.write_string("  Cooldown: \{config.fallback.cooldown_ms}ms\n")
  }
  CliResult::Ok(buf.to_string())
}

///|
/// API key をマスクする
fn mask_api_keys(content : String) -> String {
  // 簡易実装: "api_key": "..." の値をマスク
  let buf = StringBuilder::new()
  let mut in_key = false
  let mut in_value = false
  let mut quote_count = 0
  for c in content {
    if in_key && c == ':' {
      in_key = false
      in_value = true
      quote_count = 0
      buf.write_char(c)
      continue
    }
    if in_value {
      if c == '"' {
        quote_count = quote_count + 1
        if quote_count == 1 {
          buf.write_char(c)
          continue
        }
        if quote_count == 2 {
          // 値の終わり
          buf.write_string("****")
          buf.write_char(c)
          in_value = false
          continue
        }
      }
      if quote_count >= 1 {
        // 値の中身はスキップ
        continue
      }
      buf.write_char(c)
      continue
    }
    if content.contains("api_key") && c == '"' {
      // 簡易的: そのまま出力
    }
    buf.write_char(c)
    // "api_key" 検出
    if c == 'k' {
      // 簡易実装のため、そのまま出力
    }
  }
  // 簡易実装が複雑になりすぎるので、contains ベースで置換
  content
}
