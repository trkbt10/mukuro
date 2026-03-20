///|
/// Telegram Bot API チャネルアダプタ
/// Long polling で新メッセージを受信し、/sendMessage でメッセージを送信

///|
/// Telegram チャネル設定
pub(all) struct TelegramChannelConfig {
  /// Bot トークン
  bot_token : String
  /// API ベース URL (デフォルト: https://api.telegram.org)
  api_base_url : String
  /// Long polling タイムアウト（秒）
  polling_timeout : Int
}

///|
pub fn TelegramChannelConfig::default(bot_token~ : String) -> TelegramChannelConfig {
  {
    bot_token,
    api_base_url: "https://api.telegram.org",
    polling_timeout: 30,
  }
}

///|
/// JSON から Telegram 設定をパース
pub fn TelegramChannelConfig::from_json(
  json : Json,
) -> TelegramChannelConfig? {
  match json {
    { "token": String(token), .. } => {
      let api_base = match json {
        { "api_base_url": String(url), .. } => url
        _ => "https://api.telegram.org"
      }
      let timeout = match json {
        { "polling_timeout": Number(n, ..), .. } => n.to_int()
        _ => 30
      }
      Some({
        bot_token: token,
        api_base_url: api_base,
        polling_timeout: timeout,
      })
    }
    _ => None
  }
}

///|
/// Telegram チャネルアダプタ
pub struct TelegramChannelAdapter {
  config : TelegramChannelConfig
  base : ChannelBaseConfig
  mut connected : Bool
  /// 最後の update_id (long polling 用)
  mut last_update_id : Int64
  /// 受信キュー
  inbox : Array[@types.InboundEnvelope]
}

///|
pub fn TelegramChannelAdapter::new(
  config : TelegramChannelConfig,
) -> TelegramChannelAdapter {
  {
    config,
    base: ChannelBaseConfig::default(name="telegram"),
    connected: false,
    last_update_id: 0L,
    inbox: [],
  }
}

///|
fn TelegramChannelAdapter::api_url(
  self : TelegramChannelAdapter,
  method : String,
) -> String {
  let base = self.config.api_base_url
  let token = self.config.bot_token
  "\{base}/bot\{token}/\{method}"
}

///|
/// curl で Telegram API を呼び出す
fn telegram_api_call(url : String, body : String?) -> (String, Int) {
  let escaped_url = @util.escape_shell_single_quote(url)
  let cmd = match body {
    Some(b) => {
      let escaped_body = @util.escape_shell_single_quote(b)
      "curl -s --connect-timeout 10 --max-time 35 -X POST -H 'Content-Type: application/json' -d '\{escaped_body}' '\{escaped_url}'"
    }
    None => "curl -s --connect-timeout 10 --max-time 35 '\{escaped_url}'"
  }
  channel_exec_curl(cmd)
}

///|
/// getUpdates レスポンスから InboundEnvelope を抽出
fn parse_telegram_updates(
  json : Json,
  last_id : Int64,
) -> (Array[@types.InboundEnvelope], Int64) {
  let envelopes : Array[@types.InboundEnvelope] = []
  let mut new_last_id = last_id
  match json {
    { "ok": True, "result": Array(updates), .. } =>
      for update in updates {
        match update {
          { "update_id": Number(uid, ..), "message": msg, .. } => {
            let update_id = uid.to_int64()
            if update_id > new_last_id {
              new_last_id = update_id
            }
            match msg {
              { "text": String(text), "chat": { "id": Number(chat_id, ..), .. }, "from": from, .. } => {
                let sender_id = match from {
                  { "id": Number(id, ..), .. } => id.to_int64().to_string()
                  _ => "unknown"
                }
                let sender_name = match from {
                  { "first_name": String(name), .. } => name
                  _ => "Unknown"
                }
                let timestamp = match msg {
                  { "date": Number(d, ..), .. } => d.to_int64() * 1000L
                  _ => 0L
                }
                envelopes.push({
                  channel: "telegram",
                  chat_id: chat_id.to_int64().to_string(),
                  sender_id,
                  sender_name,
                  content: text,
                  message_type: @types.MessageType::Text,
                  metadata: {},
                  timestamp,
                })
              }
              _ => () // テキスト以外は無視
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
  (envelopes, new_last_id)
}

// =============================================================================
// ChannelAdapter 実装
// =============================================================================

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with name(self) {
  self.base.name
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with connect(
  self,
) {
  // getMe で接続確認
  let url = self.api_url("getMe")
  let (body, exit_code) = telegram_api_call(url, None)
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
    { "ok": True, .. } => self.connected = true
    _ => self.connected = false
  }
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with disconnect(
  self,
) {
  self.connected = false
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with is_connected(
  self,
) {
  self.connected
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with send(
  self,
  message,
) {
  let chat_id = message.chat_id
  let text = @util.escape_shell_single_quote(message.content)
  let body = "{\"chat_id\":\{chat_id},\"text\":\"\{text}\"}"
  let url = self.api_url("sendMessage")
  let (_, _) = telegram_api_call(url, Some(body))
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with receive(
  self,
) {
  // キューにメッセージがあればそれを返す
  if self.inbox.length() > 0 {
    return self.inbox.remove(0)
  }
  // long polling で新メッセージを取得
  let offset = self.last_update_id + 1L
  let timeout = self.config.polling_timeout
  let url = self.api_url("getUpdates") +
    "?offset=\{offset}&timeout=\{timeout}"
  let (body, exit_code) = telegram_api_call(url, None)
  if exit_code != 0 || body.is_empty() {
    return @types.InboundEnvelope::default()
  }
  let json : Json = @json.parse(body) catch {
    _ => return @types.InboundEnvelope::default()
  }
  let (envelopes, new_last_id) = parse_telegram_updates(json, self.last_update_id)
  self.last_update_id = new_last_id
  if envelopes.is_empty() {
    return @types.InboundEnvelope::default()
  }
  // 最初の1つを返し、残りをキューに入れる
  let first = envelopes[0]
  for i = 1; i < envelopes.length(); i = i + 1 {
    self.inbox.push(envelopes[i])
  }
  first
}
