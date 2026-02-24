///|
/// Runtime channel bootstrap (native)

///|
struct RuntimeChannelsCell {
  mut loaded_path : String?
  ws_adapters : Array[@channels.WebSocketChannelAdapter]
  http_adapters : Array[@channels.HttpChannelAdapter]
  registered_names : Array[String]
}

///|
let runtime_channels_cell : RuntimeChannelsCell = {
  loaded_path: None,
  ws_adapters: [],
  http_adapters: [],
  registered_names: [],
}

///|
fn read_runtime_config_text(path : String) -> String? {
  let buffer_len = 65536
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file(
    @native.string_to_cstring(path),
    buffer,
    buffer_len,
  )
  if read_len <= 0 {
    return None
  }
  let data = Bytes::from_iter(buffer[:read_len].iter())
  let content = @utf8.decode(data[:]) catch { _ => return None }
  Some(content)
}

///|
fn parse_channels_array(root : Json) -> Array[Map[String, Json]] {
  match root {
    { "channels": Array(channels), .. } => {
      let result : Array[Map[String, Json]] = []
      for item in channels {
        match item {
          Object(obj) => result.push(obj)
          _ => ()
        }
      }
      result
    }
    _ => []
  }
}

///|
fn parse_channel_name(obj : Map[String, Json]) -> String? {
  match obj.get("name") {
    Some(String(name)) => if name.length() == 0 { None } else { Some(name) }
    _ => None
  }
}

///|
fn parse_channel_enabled(obj : Map[String, Json]) -> Bool {
  match obj.get("enabled") {
    Some(False) => false
    _ => true
  }
}

///|
fn parse_channel_token(obj : Map[String, Json]) -> String? {
  match obj.get("token") {
    Some(String(token)) => if token.length() == 0 { None } else { Some(token) }
    _ => None
  }
}

///|
fn parse_channel_webhook_url(obj : Map[String, Json]) -> String? {
  match obj.get("webhook_url") {
    Some(String(url)) => if url.length() == 0 { None } else { Some(url) }
    _ => None
  }
}

///|
fn parse_channel_options(obj : Map[String, Json]) -> Map[String, Json] {
  match obj.get("options") {
    Some(Object(options)) => options
    _ => {}
  }
}

///|
fn option_string(options : Map[String, Json], key : String) -> String? {
  match options.get(key) {
    Some(String(value)) => if value.length() == 0 { None } else { Some(value) }
    _ => None
  }
}

///|
fn option_int(options : Map[String, Json], key : String) -> Int? {
  match options.get(key) {
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
fn detect_channel_kind(
  name : String,
  webhook_url : String?,
  options : Map[String, Json],
) -> String {
  let explicit = option_string(options, "type").unwrap_or(
    option_string(options, "kind").unwrap_or(""),
  )
  if explicit == "websocket" || explicit == "ws" {
    return "websocket"
  }
  if explicit == "http" {
    return "http"
  }
  let option_url = option_string(options, "url").unwrap_or("")
  if option_url.has_prefix("ws://") || option_url.has_prefix("wss://") {
    return "websocket"
  }
  if name.contains("websocket") || name.contains("-ws") {
    return "websocket"
  }
  match webhook_url {
    Some(url) =>
      if url.has_prefix("ws://") || url.has_prefix("wss://") {
        "websocket"
      } else {
        "http"
      }
    None => "unknown"
  }
}

///|
fn register_websocket_channel(
  name : String,
  token : String?,
  webhook_url : String?,
  options : Map[String, Json],
) -> Unit {
  let ws_url = option_string(options, "url").unwrap_or(
    webhook_url.unwrap_or(""),
  )
  if ws_url.length() == 0 {
    return
  }
  let receive_timeout = option_int(options, "receive_timeout_ms").unwrap_or(50)
  let config : @channels.WebSocketChannelConfig = {
    ..@channels.WebSocketChannelConfig::default(name~, url=ws_url),
    auth_token: token,
    receive_timeout_ms: receive_timeout,
  }
  runtime_channels_cell.ws_adapters.push(
    @channels.WebSocketChannelAdapter::new(config),
  )
  let index = runtime_channels_cell.ws_adapters.length() - 1
  @interfaces.ChannelManager::register(
    global_channel_manager,
    runtime_channels_cell.ws_adapters[index],
  )
  runtime_channels_cell.registered_names.push(name)
}

///|
fn register_http_channel(
  name : String,
  token : String?,
  webhook_url : String?,
) -> Unit {
  let config : @channels.HttpChannelConfig = {
    ..@channels.HttpChannelConfig::default(name~),
    auth_token: token,
    webhook_url,
  }
  runtime_channels_cell.http_adapters.push(
    @channels.HttpChannelAdapter::new(config),
  )
  let index = runtime_channels_cell.http_adapters.length() - 1
  @interfaces.ChannelManager::register(
    global_channel_manager,
    runtime_channels_cell.http_adapters[index],
  )
  runtime_channels_cell.registered_names.push(name)
}

///|
pub fn bootstrap_runtime_channels_from_config(path : String) -> Unit {
  match runtime_channels_cell.loaded_path {
    Some(loaded) => if loaded == path { return }
    None => ()
  }
  for name in runtime_channels_cell.registered_names {
    @interfaces.ChannelManager::unregister(global_channel_manager, name)
  }
  runtime_channels_cell.ws_adapters.clear()
  runtime_channels_cell.http_adapters.clear()
  runtime_channels_cell.registered_names.clear()

  let content = read_runtime_config_text(path).unwrap_or("")
  if content.length() == 0 {
    runtime_channels_cell.loaded_path = Some(path)
    return
  }
  let root = @json.parse(content) catch {
    _ => {
      runtime_channels_cell.loaded_path = Some(path)
      return
    }
  }
  let channels = parse_channels_array(root)
  for item in channels {
    let name = parse_channel_name(item).unwrap_or("")
    if name.length() == 0 || !parse_channel_enabled(item) {
      continue
    }
    let token = parse_channel_token(item)
    let webhook_url = parse_channel_webhook_url(item)
    let options = parse_channel_options(item)
    let kind = detect_channel_kind(name, webhook_url, options)
    if kind == "websocket" {
      register_websocket_channel(name, token, webhook_url, options)
    } else if kind == "http" {
      register_http_channel(name, token, webhook_url)
    }
  }
  runtime_channels_cell.loaded_path = Some(path)
}

///|
pub fn runtime_channel_holding_count_for_test() -> Int {
  runtime_channels_cell.ws_adapters.length() +
  runtime_channels_cell.http_adapters.length()
}
