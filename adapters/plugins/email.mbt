///|
/// Email Plugin
/// Provides email integration via IMAP/SMTP and Gmail API

///|
/// Email message
pub(all) struct EmailMessage {
  /// Unique ID
  id : String
  /// Thread ID
  thread_id : String
  /// Subject
  subject : String
  /// From address
  from : EmailAddress
  /// To addresses
  to : Array[EmailAddress]
  /// CC addresses
  cc : Array[EmailAddress]
  /// BCC addresses
  bcc : Array[EmailAddress]
  /// Plain text body
  body_text : String
  /// HTML body
  body_html : String
  /// Attachments
  attachments : Array[EmailAttachment]
  /// Labels/folders
  labels : Array[String]
  /// Is read
  is_read : Bool
  /// Is starred/flagged
  is_starred : Bool
  /// Date (ISO 8601)
  date : String
  /// Snippet/preview
  snippet : String
}

///|
/// Email address
pub(all) struct EmailAddress {
  /// Display name
  name : String
  /// Email address
  email : String
}

///|
/// Format email address
pub fn EmailAddress::format(self : EmailAddress) -> String {
  if self.name.length() > 0 {
    "\{self.name} <\{self.email}>"
  } else {
    self.email
  }
}

///|
/// Email attachment
pub(all) struct EmailAttachment {
  /// Filename
  filename : String
  /// MIME type
  mime_type : String
  /// Size in bytes
  size : Int64
  /// Attachment ID (for downloading)
  attachment_id : String
}

///|
/// Search filter
pub(all) struct EmailSearchFilter {
  /// Search query (Gmail-style)
  query : String?
  /// From filter
  from : String?
  /// To filter
  to : String?
  /// Subject contains
  subject : String?
  /// Has attachment
  has_attachment : Bool?
  /// Is unread
  is_unread : Bool?
  /// After date (ISO 8601)
  after : String?
  /// Before date (ISO 8601)
  before : String?
  /// Label/folder
  label : String?
}

///|
/// Default search filter
pub fn EmailSearchFilter::new() -> EmailSearchFilter {
  {
    query: None,
    from: None,
    to: None,
    subject: None,
    has_attachment: None,
    is_unread: None,
    after: None,
    before: None,
    label: None,
  }
}

///|
/// Email plugin configuration
pub(all) struct EmailPluginConfig {
  /// Plugin name
  name : String
  /// Provider (gmail, outlook, imap)
  provider : String
  /// Default mailbox/folder
  default_mailbox : String
  /// Max results per search
  max_results : Int
}

///|
/// Default email config
pub fn EmailPluginConfig::default(name~ : String) -> EmailPluginConfig {
  { name, provider: "gmail", default_mailbox: "INBOX", max_results: 50 }
}

///|
/// Email plugin
pub struct EmailPlugin {
  config : EmailPluginConfig
  /// Cached messages
  messages : Map[String, EmailMessage]
  /// Drafts
  drafts : Map[String, EmailMessage]
  /// Next ID counter
  mut next_id : Int
}

///|
/// Create new email plugin
pub fn EmailPlugin::new(config : EmailPluginConfig) -> EmailPlugin {
  { config, messages: {}, drafts: {}, next_id: 1 }
}

///|
/// Generate message ID
fn EmailPlugin::generate_id(self : EmailPlugin) -> String {
  let id = "msg_\{self.next_id}"
  self.next_id = self.next_id + 1
  id
}

///|
/// Compose new email
pub fn EmailPlugin::compose(
  self : EmailPlugin,
  to : Array[EmailAddress],
  subject : String,
  body_text~ : String = "",
  body_html~ : String = "",
  cc~ : Array[EmailAddress] = [],
  bcc~ : Array[EmailAddress] = [],
  attachments~ : Array[EmailAttachment] = [],
) -> EmailMessage {
  let id = self.generate_id()
  let message : EmailMessage = {
    id,
    thread_id: id,
    subject,
    from: { name: "", email: "" }, // Will be filled by actual send
    to,
    cc,
    bcc,
    body_text,
    body_html,
    attachments,
    labels: ["DRAFT"],
    is_read: true,
    is_starred: false,
    date: "",
    snippet: if body_text.length() > 100 {
      body_text.substring(end=100)
    } else {
      body_text
    },
  }
  self.drafts[id] = message
  message
}

///|
/// Get message by ID
pub fn EmailPlugin::get_message(
  self : EmailPlugin,
  id : String,
) -> EmailMessage? {
  match self.messages.get(id) {
    Some(m) => Some(m)
    None => self.drafts.get(id)
  }
}

///|
/// Search messages
pub fn EmailPlugin::search(
  self : EmailPlugin,
  filter : EmailSearchFilter,
  limit~ : Int? = None,
) -> Array[EmailMessage] {
  let actual_limit = match limit {
    Some(l) => l
    None => self.config.max_results
  }
  let results : Array[EmailMessage] = []
  for _, msg in self.messages {
    // Apply filters
    match filter.from {
      Some(from) =>
        if not(msg.from.email.contains(from)) &&
          not(msg.from.name.contains(from)) {
          continue
        }
      None => ()
    }
    match filter.subject {
      Some(subj) => if not(msg.subject.contains(subj)) { continue }
      None => ()
    }
    match filter.is_unread {
      Some(unread) => if msg.is_read == unread { continue }
      None => ()
    }
    match filter.has_attachment {
      Some(has_att) =>
        if (msg.attachments.length() > 0) != has_att {
          continue
        }
      None => ()
    }
    match filter.label {
      Some(label) => {
        let mut found = false
        for l in msg.labels {
          if l == label {
            found = true
            break
          }
        }
        if not(found) {
          continue
        }
      }
      None => ()
    }
    // Date filters (simple string comparison for ISO 8601)
    match filter.after {
      Some(after) => if msg.date < after { continue }
      None => ()
    }
    match filter.before {
      Some(before) => if msg.date > before { continue }
      None => ()
    }
    results.push(msg)
    if results.length() >= actual_limit {
      break
    }
  }
  results
}

///|
/// Mark as read
pub fn EmailPlugin::mark_read(self : EmailPlugin, id : String) -> Bool {
  match self.messages.get(id) {
    Some(msg) => {
      let updated : EmailMessage = {
        ..msg,
        is_read: true,
        labels: remove_label(msg.labels, "UNREAD"),
      }
      self.messages[id] = updated
      true
    }
    None => false
  }
}

///|
/// Mark as unread
pub fn EmailPlugin::mark_unread(self : EmailPlugin, id : String) -> Bool {
  match self.messages.get(id) {
    Some(msg) => {
      let labels = msg.labels
      let mut has_unread = false
      for l in labels {
        if l == "UNREAD" {
          has_unread = true
          break
        }
      }
      let new_labels = if has_unread {
        labels
      } else {
        let arr : Array[String] = []
        for l in labels {
          arr.push(l)
        }
        arr.push("UNREAD")
        arr
      }
      let updated : EmailMessage = { ..msg, is_read: false, labels: new_labels }
      self.messages[id] = updated
      true
    }
    None => false
  }
}

///|
/// Star/flag message
pub fn EmailPlugin::star(self : EmailPlugin, id : String) -> Bool {
  match self.messages.get(id) {
    Some(msg) => {
      let updated : EmailMessage = { ..msg, is_starred: true }
      self.messages[id] = updated
      true
    }
    None => false
  }
}

///|
/// Unstar message
pub fn EmailPlugin::unstar(self : EmailPlugin, id : String) -> Bool {
  match self.messages.get(id) {
    Some(msg) => {
      let updated : EmailMessage = { ..msg, is_starred: false }
      self.messages[id] = updated
      true
    }
    None => false
  }
}

///|
/// Add label
pub fn EmailPlugin::add_label(
  self : EmailPlugin,
  id : String,
  label : String,
) -> Bool {
  match self.messages.get(id) {
    Some(msg) => {
      let labels = msg.labels
      let mut has_label = false
      for l in labels {
        if l == label {
          has_label = true
          break
        }
      }
      if not(has_label) {
        let new_labels : Array[String] = []
        for l in labels {
          new_labels.push(l)
        }
        new_labels.push(label)
        let updated : EmailMessage = { ..msg, labels: new_labels }
        self.messages[id] = updated
      }
      true
    }
    None => false
  }
}

///|
/// Remove label
pub fn EmailPlugin::remove_label_from_message(
  self : EmailPlugin,
  id : String,
  label : String,
) -> Bool {
  match self.messages.get(id) {
    Some(msg) => {
      let updated : EmailMessage = {
        ..msg,
        labels: remove_label(msg.labels, label),
      }
      self.messages[id] = updated
      true
    }
    None => false
  }
}

///|
fn remove_label(labels : Array[String], label : String) -> Array[String] {
  let result : Array[String] = []
  for l in labels {
    if l != label {
      result.push(l)
    }
  }
  result
}

///|
/// Delete message (move to trash)
pub fn EmailPlugin::delete(self : EmailPlugin, id : String) -> Bool {
  match self.messages.get(id) {
    Some(msg) => {
      let updated : EmailMessage = {
        ..msg,
        labels: replace_labels(msg.labels, "INBOX", "TRASH"),
      }
      self.messages[id] = updated
      true
    }
    None => {
      // Check drafts
      match self.drafts.get(id) {
        Some(_) => {
          self.drafts.remove(id)
          true
        }
        None => false
      }
    }
  }
}

///|
fn replace_labels(
  labels : Array[String],
  old_label : String,
  new_label : String,
) -> Array[String] {
  let result : Array[String] = []
  let mut found_old = false
  for l in labels {
    if l == old_label {
      found_old = true
    } else {
      result.push(l)
    }
  }
  if found_old {
    result.push(new_label)
  }
  result
}

///|
/// Convert message to JSON
fn message_to_json(msg : EmailMessage) -> Json {
  let to_json : Array[Json] = []
  for addr in msg.to {
    to_json.push({ "name": addr.name, "email": addr.email })
  }
  let cc_json : Array[Json] = []
  for addr in msg.cc {
    cc_json.push({ "name": addr.name, "email": addr.email })
  }
  let att_json : Array[Json] = []
  for att in msg.attachments {
    att_json.push(
      {
        "filename": att.filename,
        "mime_type": att.mime_type,
        "size": Json::number(att.size.to_double()),
        "attachment_id": att.attachment_id,
      },
    )
  }
  let labels_json : Array[Json] = []
  for l in msg.labels {
    labels_json.push(Json::string(l))
  }
  {
    "id": msg.id,
    "thread_id": msg.thread_id,
    "subject": msg.subject,
    "from": { "name": msg.from.name, "email": msg.from.email },
    "to": Json::array(to_json),
    "cc": Json::array(cc_json),
    "body_text": msg.body_text,
    "body_html": msg.body_html,
    "attachments": Json::array(att_json),
    "labels": Json::array(labels_json),
    "is_read": Json::boolean(msg.is_read),
    "is_starred": Json::boolean(msg.is_starred),
    "date": msg.date,
    "snippet": msg.snippet,
  }
}

///|
/// Handle JSON-RPC request
pub fn EmailPlugin::handle_request(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "compose" => self.handle_compose(request)
    "send" => self.handle_send(request)
    "get" => self.handle_get(request)
    "search" => self.handle_search(request)
    "mark_read" => self.handle_mark_read(request)
    "mark_unread" => self.handle_mark_unread(request)
    "star" => self.handle_star(request)
    "unstar" => self.handle_unstar(request)
    "add_label" => self.handle_add_label(request)
    "remove_label" => self.handle_remove_label(request)
    "delete" => self.handle_delete(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn EmailPlugin::handle_compose(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (to, subject) = match request.params {
    Some({ "to": Array(to_arr), "subject": String(subj), .. }) => {
      let to_addrs : Array[EmailAddress] = []
      for addr in to_arr {
        match addr {
          { "email": String(email), .. } => {
            let name = match addr {
              { "name": String(n), .. } => n
              _ => ""
            }
            to_addrs.push({ name, email })
          }
          String(email) => to_addrs.push({ name: "", email })
          _ => ()
        }
      }
      (to_addrs, subj)
    }
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'to' or 'subject' parameter",
        id=request.id,
      )
  }
  let body_text = match request.params {
    Some({ "body_text": String(b), .. }) => b
    Some({ "body": String(b), .. }) => b
    _ => ""
  }
  let body_html = match request.params {
    Some({ "body_html": String(b), .. }) => b
    _ => ""
  }
  let msg = self.compose(to, subject, body_text~, body_html~)
  @interfaces.JsonRpcResponse::success(result=message_to_json(msg), id=request.id)
}

///|
fn EmailPlugin::handle_send(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let msg_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  match self.drafts.get(msg_id) {
    Some(msg) => {
      // Move from drafts to sent
      let sent : EmailMessage = {
        ..msg,
        labels: ["SENT"],
        date: "2025-01-01T00:00:00Z", // Would be actual time
      }
      self.messages[msg_id] = sent
      self.drafts.remove(msg_id)
      @interfaces.JsonRpcResponse::success(
        result={ "sent": true, "id": msg_id },
        id=request.id,
      )
    }
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Draft not found",
        id=request.id,
      )
  }
}

///|
fn EmailPlugin::handle_get(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let msg_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  match self.get_message(msg_id) {
    Some(msg) =>
      @interfaces.JsonRpcResponse::success(
        result=message_to_json(msg),
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Message not found",
        id=request.id,
      )
  }
}

///|
fn EmailPlugin::handle_search(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let filter = EmailSearchFilter::new()
  let updated_filter = match request.params {
    Some(params) => {
      let mut f = filter
      match params {
        { "query": String(q), .. } => f = { ..f, query: Some(q) }
        _ => ()
      }
      match params {
        { "from": String(fr), .. } => f = { ..f, from: Some(fr) }
        _ => ()
      }
      match params {
        { "subject": String(s), .. } => f = { ..f, subject: Some(s) }
        _ => ()
      }
      match params {
        { "is_unread": True, .. } => f = { ..f, is_unread: Some(true) }
        { "is_unread": False, .. } => f = { ..f, is_unread: Some(false) }
        _ => ()
      }
      match params {
        { "label": String(l), .. } => f = { ..f, label: Some(l) }
        _ => ()
      }
      f
    }
    None => filter
  }
  let limit = match request.params {
    Some({ "limit": Number(l, ..), .. }) => Some(l.to_int())
    _ => None
  }
  let results = self.search(updated_filter, limit~)
  let results_json : Array[Json] = []
  for msg in results {
    results_json.push(message_to_json(msg))
  }
  @interfaces.JsonRpcResponse::success(
    result={ "messages": Json::array(results_json) },
    id=request.id,
  )
}

///|
fn EmailPlugin::handle_mark_read(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let msg_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  let success = self.mark_read(msg_id)
  @interfaces.JsonRpcResponse::success(result={ "success": success }, id=request.id)
}

///|
fn EmailPlugin::handle_mark_unread(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let msg_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  let success = self.mark_unread(msg_id)
  @interfaces.JsonRpcResponse::success(result={ "success": success }, id=request.id)
}

///|
fn EmailPlugin::handle_star(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let msg_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  let success = self.star(msg_id)
  @interfaces.JsonRpcResponse::success(result={ "success": success }, id=request.id)
}

///|
fn EmailPlugin::handle_unstar(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let msg_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  let success = self.unstar(msg_id)
  @interfaces.JsonRpcResponse::success(result={ "success": success }, id=request.id)
}

///|
fn EmailPlugin::handle_add_label(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (msg_id, label) = match request.params {
    Some({ "id": String(i), "label": String(l), .. }) => (i, l)
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' or 'label' parameter",
        id=request.id,
      )
  }
  let success = self.add_label(msg_id, label)
  @interfaces.JsonRpcResponse::success(result={ "success": success }, id=request.id)
}

///|
fn EmailPlugin::handle_remove_label(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (msg_id, label) = match request.params {
    Some({ "id": String(i), "label": String(l), .. }) => (i, l)
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' or 'label' parameter",
        id=request.id,
      )
  }
  let success = self.remove_label_from_message(msg_id, label)
  @interfaces.JsonRpcResponse::success(result={ "success": success }, id=request.id)
}

///|
fn EmailPlugin::handle_delete(
  self : EmailPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let msg_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  let success = self.delete(msg_id)
  @interfaces.JsonRpcResponse::success(result={ "deleted": success }, id=request.id)
}
