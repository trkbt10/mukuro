///|
/// Discord Bot チャネルアダプタ
/// REST API で送受信。Gateway WebSocket は将来拡張。

///|
/// Discord チャネル設定
pub(all) struct DiscordChannelConfig {
  /// Bot トークン
  bot_token : String
  /// API ベース URL
  api_base_url : String
  /// 監視するチャネル ID のリスト
  channel_ids : Array[String]
  /// ポーリング間隔（秒）
  polling_interval : Int
}

///|
pub fn DiscordChannelConfig::default(
  bot_token~ : String,
) -> DiscordChannelConfig {
  {
    bot_token,
    api_base_url: "https://discord.com/api/v10",
    channel_ids: [],
    polling_interval: 5,
  }
}

///|
pub fn DiscordChannelConfig::from_json(json : Json) -> DiscordChannelConfig? {
  match json {
    { "token": String(token), .. } => {
      let api_base = match json {
        { "api_base_url": String(url), .. } => url
        _ => "https://discord.com/api/v10"
      }
      let channel_ids : Array[String] = match json {
        { "channel_ids": Array(arr), .. } => {
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
      let polling = match json {
        { "polling_interval": Number(n, ..), .. } => n.to_int()
        _ => 5
      }
      Some({
        bot_token: token,
        api_base_url: api_base,
        channel_ids,
        polling_interval: polling,
      })
    }
    _ => None
  }
}

///|
/// Discord チャネルアダプタ
pub struct DiscordChannelAdapter {
  config : DiscordChannelConfig
  base : ChannelBaseConfig
  mut connected : Bool
  /// 最後に見た message ID (ポーリング用)
  last_message_id : String?
  /// 受信キュー
  inbox : Array[@types.InboundEnvelope]
}

///|
pub fn DiscordChannelAdapter::new(
  config : DiscordChannelConfig,
) -> DiscordChannelAdapter {
  {
    config,
    base: ChannelBaseConfig::default(name="discord"),
    connected: false,
    last_message_id: None,
    inbox: [],
  }
}

///|
fn discord_api_call(
  url : String,
  method : String,
  token : String,
  body : String?,
) -> (String, Int) {
  let escaped_url = discord_escape_sq(url)
  let mut cmd = "curl -s --connect-timeout 10 --max-time 15 -X \{method} -H 'Authorization: Bot \{token}' -H 'Content-Type: application/json'"
  match body {
    Some(b) => {
      let escaped_body = discord_escape_sq(b)
      cmd = cmd + " -d '\{escaped_body}'"
    }
    None => ()
  }
  cmd = cmd + " '\{escaped_url}'"
  let cmd_bytes = @bytes.to_utf8_cstring(cmd)
  let mode_bytes = @bytes.to_utf8_cstring("r")
  let handle = discord_popen_handle(cmd_bytes, mode_bytes)
  if handle == 0L {
    return ("", -1)
  }
  let buffer_size = 65536
  let buffer = Bytes::new(buffer_size)
  let bytes_read = discord_fread_handle(buffer, 1, buffer_size, handle)
  let exit_raw = discord_pclose_handle(handle)
  let exit_code = (exit_raw.reinterpret_as_uint() >> 8)
    .land(0xFFU)
    .reinterpret_as_int()
  let stdout = if bytes_read > 0 {
    match @bytes.decode_utf8(buffer[:bytes_read]) {
      Some(s) => s
      None => ""
    }
  } else {
    ""
  }
  (stdout, exit_code)
}

///|
fn discord_escape_sq(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if c == '\'' {
      buf.write_string("'\\''")
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
#borrow(command, mode)
extern "C" fn discord_popen_handle(
  command : Bytes,
  mode : Bytes,
) -> Int64 = "moonbit_popen_bytes"

///|
extern "C" fn discord_pclose_handle(handle : Int64) -> Int = "moonbit_pclose_handle"

///|
#borrow(buffer)
extern "C" fn discord_fread_handle(
  buffer : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fread_handle"

///|
/// Discord メッセージ配列から InboundEnvelope を抽出
fn parse_discord_messages(
  json : Json,
  bot_user_id : String,
) -> Array[@types.InboundEnvelope] {
  let envelopes : Array[@types.InboundEnvelope] = []
  match json {
    Array(messages) =>
      for msg in messages {
        match msg {
          {
            "content": String(content),
            "channel_id": String(channel_id),
            "author": { "id": String(author_id), "username": String(username), .. },
            ..
          } => {
            // Bot 自身のメッセージは無視
            if author_id == bot_user_id {
              continue
            }
            let timestamp = match msg {
              { "timestamp": String(_ts), .. } => 0L // ISO8601 パースは省略
              _ => 0L
            }
            envelopes.push({
              channel: "discord",
              chat_id: channel_id,
              sender_id: author_id,
              sender_name: username,
              content,
              message_type: @types.MessageType::Text,
              metadata: {},
              timestamp,
            })
          }
          _ => ()
        }
      }
    _ => ()
  }
  envelopes
}

// =============================================================================
// ChannelAdapter 実装
// =============================================================================

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with name(self) {
  self.base.name
}

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with connect(
  self,
) {
  // /users/@me で接続確認
  let url = self.config.api_base_url + "/users/@me"
  let (body, exit_code) = discord_api_call(url, "GET", self.config.bot_token, None)
  if exit_code != 0 || body.is_empty() {
    self.connected = false
    return
  }
  let json : Json = @json.parse(body) catch {
    _ => {
      self.connected = false
      return
    }
  }
  match json {
    { "id": String(_), .. } => self.connected = true
    _ => self.connected = false
  }
}

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with disconnect(
  self,
) {
  self.connected = false
}

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with is_connected(
  self,
) {
  self.connected
}

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with send(
  self,
  message,
) {
  let chat_id = message.chat_id
  let escaped_content = discord_escape_sq(message.content)
  let body = "{\"content\":\"\{escaped_content}\"}"
  let url = self.config.api_base_url + "/channels/\{chat_id}/messages"
  let (_, _) = discord_api_call(url, "POST", self.config.bot_token, Some(body))
}

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with receive(
  self,
) {
  if self.inbox.length() > 0 {
    return self.inbox.remove(0)
  }
  // 監視チャネルからメッセージを取得
  for channel_id in self.config.channel_ids {
    let url = self.config.api_base_url + "/channels/\{channel_id}/messages?limit=10"
    let (body, exit_code) = discord_api_call(url, "GET", self.config.bot_token, None)
    if exit_code != 0 || body.is_empty() {
      continue
    }
    let json : Json = @json.parse(body) catch { _ => continue }
    let envelopes = parse_discord_messages(json, "")
    for env in envelopes {
      self.inbox.push(env)
    }
  }
  if self.inbox.length() > 0 {
    return self.inbox.remove(0)
  }
  @types.InboundEnvelope::default()
}
