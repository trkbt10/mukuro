///|
/// Allowlist — チャネルごとの送信者フィルタリング

///|
/// Allowlist 設定
pub(all) struct AllowlistConfig {
  /// 有効かどうか
  enabled : Bool
  /// 対象チャネル名
  channel : String
  /// 許可された送信者 ID
  senders : Array[String]
  /// 許可されたチャット ID (None = 全チャット許可)
  chat_ids : Array[String]?
}

///|
/// Allowlist マネージャ
pub struct AllowlistManager {
  configs : Array[AllowlistConfig]
}

///|
pub fn AllowlistManager::new() -> AllowlistManager {
  { configs: [] }
}

///|
/// Allowlist 設定を追加
pub fn AllowlistManager::add(
  self : AllowlistManager,
  config : AllowlistConfig,
) -> Unit {
  self.configs.push(config)
}

///|
/// 送信者が許可されているか確認
/// allowlist が設定されていないチャネルは全て許可
pub fn AllowlistManager::is_allowed(
  self : AllowlistManager,
  channel : String,
  sender_id : String,
  chat_id : String,
) -> Bool {
  // このチャネルの allowlist を検索
  let mut found_config = false
  for config in self.configs {
    if config.channel != channel {
      continue
    }
    if not(config.enabled) {
      continue
    }
    found_config = true
    // チャット ID フィルタ
    match config.chat_ids {
      Some(ids) =>
        if not(ids.is_empty()) {
          let mut chat_allowed = false
          for id in ids {
            if id == chat_id {
              chat_allowed = true
              break
            }
          }
          if not(chat_allowed) {
            return false
          }
        }
      None => ()
    }
    // 送信者フィルタ
    for allowed in config.senders {
      if allowed == sender_id {
        return true
      }
    }
    // senders が空の場合は全員許可
    if config.senders.is_empty() {
      return true
    }
    return false
  }
  // allowlist 設定が見つからなければ全員許可
  if not(found_config) {
    return true
  }
  false
}

///|
/// JSON から Allowlist 設定をパース
pub fn AllowlistConfig::from_json(json : Json) -> AllowlistConfig? {
  match json {
    { "channel": String(channel), .. } => {
      let enabled = match json {
        { "enabled": True, .. } => true
        { "enabled": False, .. } => false
        _ => true
      }
      let senders : Array[String] = match json {
        { "senders": Array(arr), .. } => {
          let result : Array[String] = []
          for item in arr {
            match item {
              String(s) => result.push(s)
              _ => ()
            }
          }
          result
        }
        _ => []
      }
      let chat_ids : Array[String]? = match json {
        { "chat_ids": Array(arr), .. } => {
          let result : Array[String] = []
          for item in arr {
            match item {
              String(s) => result.push(s)
              _ => ()
            }
          }
          Some(result)
        }
        _ => None
      }
      Some({ enabled, channel, senders, chat_ids })
    }
    _ => None
  }
}

///|
/// config.json の allowlists セクションからロード
pub fn load_allowlists_from_json(json : Json) -> AllowlistManager {
  let manager = AllowlistManager::new()
  match json {
    { "allowlists": Array(configs), .. } =>
      for config_json in configs {
        match AllowlistConfig::from_json(config_json) {
          Some(config) => manager.add(config)
          None => ()
        }
      }
    _ => ()
  }
  manager
}
