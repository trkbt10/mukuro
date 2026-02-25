///|
/// Browser Automation Plugin
/// Provides web browser control via CDP (Chrome DevTools Protocol)

///|
/// Browser action types
pub(all) enum BrowserAction {
  /// Navigate to URL
  Navigate(String)
  /// Click element by selector
  Click(String)
  /// Type text into element
  Type(selector~ : String, text~ : String)
  /// Take screenshot
  Screenshot(full_page~ : Bool)
  /// Execute JavaScript
  Evaluate(String)
  /// Wait for selector
  WaitFor(selector~ : String, timeout_ms~ : Int)
  /// Get element text
  GetText(String)
  /// Get element attribute
  GetAttribute(selector~ : String, attribute~ : String)
  /// Scroll page
  Scroll(x~ : Int, y~ : Int)
  /// Go back
  Back
  /// Go forward
  Forward
  /// Refresh page
  Refresh
}

///|
/// Element selector
pub(all) struct ElementSelector {
  /// CSS selector
  css : String?
  /// XPath selector
  xpath : String?
  /// Text content selector
  text : String?
  /// Selector index (for multiple matches)
  index : Int
}

///|
/// Default element selector
pub fn ElementSelector::css(selector : String) -> ElementSelector {
  { css: Some(selector), xpath: None, text: None, index: 0 }
}

///|
pub fn ElementSelector::xpath(selector : String) -> ElementSelector {
  { css: None, xpath: Some(selector), text: None, index: 0 }
}

///|
pub fn ElementSelector::by_text(text : String) -> ElementSelector {
  { css: None, xpath: None, text: Some(text), index: 0 }
}

///|
/// Browser page state
pub(all) struct PageState {
  /// Current URL
  url : String
  /// Page title
  title : String
  /// Page ready state
  ready_state : String
  /// Viewport width
  viewport_width : Int
  /// Viewport height
  viewport_height : Int
}

///|
/// Screenshot result
pub(all) struct ScreenshotResult {
  /// Base64 encoded image data
  data : String
  /// Image format (png, jpeg)
  format : String
  /// Image width
  width : Int
  /// Image height
  height : Int
}

///|
/// Browser plugin configuration
pub(all) struct BrowserPluginConfig {
  /// Plugin name
  name : String
  /// CDP endpoint URL
  cdp_endpoint : String
  /// Default timeout in milliseconds
  default_timeout_ms : Int
  /// Headless mode
  headless : Bool
  /// Default viewport width
  viewport_width : Int
  /// Default viewport height
  viewport_height : Int
}

///|
/// Default browser config
pub fn BrowserPluginConfig::default(name~ : String) -> BrowserPluginConfig {
  {
    name,
    cdp_endpoint: "http://localhost:9222",
    default_timeout_ms: 30000,
    headless: true,
    viewport_width: 1280,
    viewport_height: 720,
  }
}

///|
/// Browser plugin
pub struct BrowserPlugin {
  config : BrowserPluginConfig
  /// Current page state
  mut page_state : PageState?
  /// Action history
  action_history : Array[BrowserAction]
  /// Is connected to browser
  mut is_connected : Bool
}

///|
/// Create new browser plugin
pub fn BrowserPlugin::new(config : BrowserPluginConfig) -> BrowserPlugin {
  { config, page_state: None, action_history: [], is_connected: false }
}

///|
/// Convert action to JSON-RPC params
pub fn BrowserPlugin::action_to_params(action : BrowserAction) -> Json {
  match action {
    BrowserAction::Navigate(url) => { "action": "navigate", "url": url }
    BrowserAction::Click(selector) => { "action": "click", "selector": selector }
    BrowserAction::Type(selector~, text~) =>
      { "action": "type", "selector": selector, "text": text }
    BrowserAction::Screenshot(full_page~) =>
      { "action": "screenshot", "full_page": full_page }
    BrowserAction::Evaluate(script) =>
      { "action": "evaluate", "script": script }
    BrowserAction::WaitFor(selector~, timeout_ms~) =>
      {
        "action": "wait_for",
        "selector": selector,
        "timeout_ms": Json::number(timeout_ms.to_double()),
      }
    BrowserAction::GetText(selector) =>
      { "action": "get_text", "selector": selector }
    BrowserAction::GetAttribute(selector~, attribute~) =>
      { "action": "get_attribute", "selector": selector, "attribute": attribute }
    BrowserAction::Scroll(x~, y~) =>
      {
        "action": "scroll",
        "x": Json::number(x.to_double()),
        "y": Json::number(y.to_double()),
      }
    BrowserAction::Back => { "action": "back" }
    BrowserAction::Forward => { "action": "forward" }
    BrowserAction::Refresh => { "action": "refresh" }
  }
}

///|
/// Parse page state from JSON
pub fn BrowserPlugin::parse_page_state(json : Json) -> PageState? {
  match json {
    {
      "url": String(url),
      "title": String(title),
      "ready_state": String(ready_state),
      ..
    } => {
      let viewport_width = match json {
        { "viewport_width": Number(w, ..), .. } => w.to_int()
        _ => 0
      }
      let viewport_height = match json {
        { "viewport_height": Number(h, ..), .. } => h.to_int()
        _ => 0
      }
      Some({ url, title, ready_state, viewport_width, viewport_height })
    }
    _ => None
  }
}

///|
/// Parse screenshot result from JSON
pub fn BrowserPlugin::parse_screenshot(json : Json) -> ScreenshotResult? {
  match json {
    { "data": String(data), "format": String(format), .. } => {
      let width = match json {
        { "width": Number(w, ..), .. } => w.to_int()
        _ => 0
      }
      let height = match json {
        { "height": Number(h, ..), .. } => h.to_int()
        _ => 0
      }
      Some({ data, format, width, height })
    }
    _ => None
  }
}

///|
/// Record action in history
pub fn BrowserPlugin::record_action(
  self : BrowserPlugin,
  action : BrowserAction,
) -> Unit {
  self.action_history.push(action)
}

///|
/// Get action history
pub fn BrowserPlugin::get_history(self : BrowserPlugin) -> Array[BrowserAction] {
  self.action_history
}

///|
/// Clear action history
pub fn BrowserPlugin::clear_history(self : BrowserPlugin) -> Unit {
  self.action_history.clear()
}

///|
/// Handle JSON-RPC request
pub fn BrowserPlugin::handle_request(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "navigate" => self.handle_navigate(request)
    "click" => self.handle_click(request)
    "type" => self.handle_type(request)
    "screenshot" => self.handle_screenshot(request)
    "evaluate" => self.handle_evaluate(request)
    "wait_for" => self.handle_wait_for(request)
    "get_text" => self.handle_get_text(request)
    "get_attribute" => self.handle_get_attribute(request)
    "scroll" => self.handle_scroll(request)
    "back" => self.handle_back(request)
    "forward" => self.handle_forward(request)
    "refresh" => self.handle_refresh(request)
    "get_state" => self.handle_get_state(request)
    "connect" => self.handle_connect(request)
    "disconnect" => self.handle_disconnect(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn BrowserPlugin::handle_navigate(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let url = match request.params {
    Some({ "url": String(u), .. }) => u
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'url' parameter",
        id=request.id,
      )
  }
  self.record_action(BrowserAction::Navigate(url))
  // Actual navigation would be done by external CDP client
  @interfaces.JsonRpcResponse::success(
    result={ "action": "navigate", "url": url, "status": "pending" },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_click(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let selector = match request.params {
    Some({ "selector": String(s), .. }) => s
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'selector' parameter",
        id=request.id,
      )
  }
  self.record_action(BrowserAction::Click(selector))
  @interfaces.JsonRpcResponse::success(
    result={ "action": "click", "selector": selector, "status": "pending" },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_type(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (selector, text) = match request.params {
    Some({ "selector": String(s), "text": String(t), .. }) => (s, t)
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'selector' or 'text' parameter",
        id=request.id,
      )
  }
  self.record_action(BrowserAction::Type(selector~, text~))
  @interfaces.JsonRpcResponse::success(
    result={
      "action": "type",
      "selector": selector,
      "text": text,
      "status": "pending",
    },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_screenshot(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let full_page = match request.params {
    Some({ "full_page": True, .. }) => true
    _ => false
  }
  self.record_action(BrowserAction::Screenshot(full_page~))
  @interfaces.JsonRpcResponse::success(
    result={ "action": "screenshot", "full_page": full_page, "status": "pending" },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_evaluate(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let script = match request.params {
    Some({ "script": String(s), .. }) => s
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'script' parameter",
        id=request.id,
      )
  }
  self.record_action(BrowserAction::Evaluate(script))
  @interfaces.JsonRpcResponse::success(
    result={ "action": "evaluate", "status": "pending" },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_wait_for(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let selector = match request.params {
    Some({ "selector": String(s), .. }) => s
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'selector' parameter",
        id=request.id,
      )
  }
  let timeout_ms = match request.params {
    Some({ "timeout_ms": Number(t, ..), .. }) => t.to_int()
    _ => self.config.default_timeout_ms
  }
  self.record_action(BrowserAction::WaitFor(selector~, timeout_ms~))
  @interfaces.JsonRpcResponse::success(
    result={
      "action": "wait_for",
      "selector": selector,
      "timeout_ms": Json::number(timeout_ms.to_double()),
      "status": "pending",
    },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_get_text(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let selector = match request.params {
    Some({ "selector": String(s), .. }) => s
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'selector' parameter",
        id=request.id,
      )
  }
  self.record_action(BrowserAction::GetText(selector))
  @interfaces.JsonRpcResponse::success(
    result={ "action": "get_text", "selector": selector, "status": "pending" },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_get_attribute(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (selector, attribute) = match request.params {
    Some({ "selector": String(s), "attribute": String(a), .. }) => (s, a)
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'selector' or 'attribute' parameter",
        id=request.id,
      )
  }
  self.record_action(BrowserAction::GetAttribute(selector~, attribute~))
  @interfaces.JsonRpcResponse::success(
    result={
      "action": "get_attribute",
      "selector": selector,
      "attribute": attribute,
      "status": "pending",
    },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_scroll(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (x, y) = match request.params {
    Some({ "x": Number(px, ..), "y": Number(py, ..), .. }) =>
      (px.to_int(), py.to_int())
    _ => (0, 0)
  }
  self.record_action(BrowserAction::Scroll(x~, y~))
  @interfaces.JsonRpcResponse::success(
    result={
      "action": "scroll",
      "x": Json::number(x.to_double()),
      "y": Json::number(y.to_double()),
      "status": "pending",
    },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_back(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.record_action(BrowserAction::Back)
  @interfaces.JsonRpcResponse::success(
    result={ "action": "back", "status": "pending" },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_forward(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.record_action(BrowserAction::Forward)
  @interfaces.JsonRpcResponse::success(
    result={ "action": "forward", "status": "pending" },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_refresh(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.record_action(BrowserAction::Refresh)
  @interfaces.JsonRpcResponse::success(
    result={ "action": "refresh", "status": "pending" },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_get_state(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match self.page_state {
    Some(state) =>
      @interfaces.JsonRpcResponse::success(
        result={
          "url": state.url,
          "title": state.title,
          "ready_state": state.ready_state,
          "viewport_width": Json::number(state.viewport_width.to_double()),
          "viewport_height": Json::number(state.viewport_height.to_double()),
        },
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::success(
        result={ "url": "", "title": "", "ready_state": "uninitialized" },
        id=request.id,
      )
  }
}

///|
fn BrowserPlugin::handle_connect(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.is_connected = true
  @interfaces.JsonRpcResponse::success(
    result={ "status": "connected", "endpoint": self.config.cdp_endpoint },
    id=request.id,
  )
}

///|
fn BrowserPlugin::handle_disconnect(
  self : BrowserPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.is_connected = false
  self.page_state = None
  @interfaces.JsonRpcResponse::success(
    result={ "status": "disconnected" },
    id=request.id,
  )
}
