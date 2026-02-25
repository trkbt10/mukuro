///|
/// Calendar Plugin
/// Provides calendar integration for Google Calendar and Outlook

///|
/// Calendar event
pub(all) struct CalendarEvent {
  /// Unique ID
  id : String
  /// Event title
  title : String
  /// Event description
  description : String
  /// Start time (ISO 8601)
  start_time : String
  /// End time (ISO 8601)
  end_time : String
  /// Location
  location : String
  /// All-day event
  all_day : Bool
  /// Recurrence rule (RRULE format)
  recurrence : String?
  /// Attendees
  attendees : Array[String]
  /// Reminder minutes before
  reminder_minutes : Int
  /// Calendar ID
  calendar_id : String
  /// Status (confirmed, tentative, cancelled)
  status : String
}

///|
/// Time slot for availability
pub(all) struct TimeSlot {
  /// Start time (ISO 8601)
  start : String
  /// End time (ISO 8601)
  end : String
  /// Is busy
  busy : Bool
}

///|
/// Recurrence rule
pub(all) struct RecurrenceRule {
  /// Frequency (daily, weekly, monthly, yearly)
  frequency : String
  /// Interval (e.g., every 2 weeks)
  interval : Int
  /// Days of week (for weekly: MO,TU,WE,TH,FR,SA,SU)
  by_day : Array[String]
  /// Day of month (for monthly)
  by_month_day : Int?
  /// End date (ISO 8601) or None for infinite
  until : String?
  /// Max occurrences
  count : Int?
}

///|
/// Convert recurrence rule to RRULE string
pub fn RecurrenceRule::to_rrule(self : RecurrenceRule) -> String {
  let mut rule = "FREQ=\{self.frequency.to_upper()}"
  if self.interval > 1 {
    rule = rule + ";INTERVAL=\{self.interval}"
  }
  if self.by_day.length() > 0 {
    let mut days = ""
    for i, day in self.by_day {
      if i > 0 {
        days = days + ","
      }
      days = days + day.to_upper()
    }
    rule = rule + ";BYDAY=\{days}"
  }
  match self.by_month_day {
    Some(day) => rule = rule + ";BYMONTHDAY=\{day}"
    None => ()
  }
  match self.until {
    Some(date) => rule = rule + ";UNTIL=\{date}"
    None => ()
  }
  match self.count {
    Some(c) => rule = rule + ";COUNT=\{c}"
    None => ()
  }
  rule
}

///|
/// Calendar plugin configuration
pub(all) struct CalendarPluginConfig {
  /// Plugin name
  name : String
  /// Default calendar ID
  default_calendar_id : String
  /// Provider (google, outlook)
  provider : String
  /// Default reminder minutes
  default_reminder_minutes : Int
  /// Time zone
  timezone : String
}

///|
/// Default calendar config
pub fn CalendarPluginConfig::default(name~ : String) -> CalendarPluginConfig {
  {
    name,
    default_calendar_id: "primary",
    provider: "google",
    default_reminder_minutes: 15,
    timezone: "UTC",
  }
}

///|
/// Calendar plugin
pub struct CalendarPlugin {
  config : CalendarPluginConfig
  /// Cached events
  events : Map[String, CalendarEvent]
  /// Next ID counter
  mut next_id : Int
}

///|
/// Create new calendar plugin
pub fn CalendarPlugin::new(config : CalendarPluginConfig) -> CalendarPlugin {
  { config, events: {}, next_id: 1 }
}

///|
/// Generate event ID
fn CalendarPlugin::generate_id(self : CalendarPlugin) -> String {
  let id = "evt_\{self.next_id}"
  self.next_id = self.next_id + 1
  id
}

///|
/// Create event
pub fn CalendarPlugin::create_event(
  self : CalendarPlugin,
  title : String,
  start_time : String,
  end_time : String,
  description~ : String = "",
  location~ : String = "",
  all_day~ : Bool = false,
  recurrence~ : String? = None,
  attendees~ : Array[String] = [],
  reminder_minutes~ : Int? = None,
  calendar_id~ : String? = None,
) -> CalendarEvent {
  let id = self.generate_id()
  let cal_id = match calendar_id {
    Some(c) => c
    None => self.config.default_calendar_id
  }
  let reminder = match reminder_minutes {
    Some(r) => r
    None => self.config.default_reminder_minutes
  }
  let event : CalendarEvent = {
    id,
    title,
    description,
    start_time,
    end_time,
    location,
    all_day,
    recurrence,
    attendees,
    reminder_minutes: reminder,
    calendar_id: cal_id,
    status: "confirmed",
  }
  self.events[id] = event
  event
}

///|
/// Get event by ID
pub fn CalendarPlugin::get_event(
  self : CalendarPlugin,
  id : String,
) -> CalendarEvent? {
  self.events.get(id)
}

///|
/// Update event
pub fn CalendarPlugin::update_event(
  self : CalendarPlugin,
  id : String,
  title~ : String? = None,
  description~ : String? = None,
  start_time~ : String? = None,
  end_time~ : String? = None,
  location~ : String? = None,
) -> Bool {
  match self.events.get(id) {
    Some(event) => {
      let updated : CalendarEvent = {
        id: event.id,
        title: title.or(event.title),
        description: description.or(event.description),
        start_time: start_time.or(event.start_time),
        end_time: end_time.or(event.end_time),
        location: location.or(event.location),
        all_day: event.all_day,
        recurrence: event.recurrence,
        attendees: event.attendees,
        reminder_minutes: event.reminder_minutes,
        calendar_id: event.calendar_id,
        status: event.status,
      }
      self.events[id] = updated
      true
    }
    None => false
  }
}

///|
/// Delete event
pub fn CalendarPlugin::delete_event(self : CalendarPlugin, id : String) -> Bool {
  match self.events.get(id) {
    Some(_) => {
      self.events.remove(id)
      true
    }
    None => false
  }
}

///|
/// List events in time range
pub fn CalendarPlugin::list_events(
  self : CalendarPlugin,
  start_time~ : String? = None,
  end_time~ : String? = None,
  calendar_id~ : String? = None,
) -> Array[CalendarEvent] {
  let results : Array[CalendarEvent] = []
  for _, event in self.events {
    // Filter by calendar
    match calendar_id {
      Some(cal) => if event.calendar_id != cal { continue }
      None => ()
    }
    // Simple string comparison for time filtering (works for ISO 8601)
    match start_time {
      Some(start) => if event.end_time < start { continue }
      None => ()
    }
    match end_time {
      Some(end_val) => if event.start_time > end_val { continue }
      None => ()
    }
    results.push(event)
  }
  // Sort by start time
  for i = 0; i < results.length(); i = i + 1 {
    for j = i + 1; j < results.length(); j = j + 1 {
      if results[j].start_time < results[i].start_time {
        let temp = results[i]
        results[i] = results[j]
        results[j] = temp
      }
    }
  }
  results
}

///|
/// Check availability (find free slots)
pub fn CalendarPlugin::get_availability(
  self : CalendarPlugin,
  start_time : String,
  end_time : String,
  calendar_id~ : String? = None,
) -> Array[TimeSlot] {
  // Get all events in range
  let events = self.list_events(
    start_time=Some(start_time),
    end_time=Some(end_time),
    calendar_id~,
  )
  // Mark busy slots
  let slots : Array[TimeSlot] = []
  for event in events {
    slots.push({ start: event.start_time, end: event.end_time, busy: true })
  }
  slots
}

///|
/// Convert event to JSON
fn event_to_json(event : CalendarEvent) -> Json {
  let obj : Map[String, Json] = {
    "id": event.id,
    "title": event.title,
    "description": event.description,
    "start_time": event.start_time,
    "end_time": event.end_time,
    "location": event.location,
    "all_day": Json::boolean(event.all_day),
    "reminder_minutes": Json::number(event.reminder_minutes.to_double()),
    "calendar_id": event.calendar_id,
    "status": event.status,
  }
  match event.recurrence {
    Some(r) => obj["recurrence"] = Json::string(r)
    None => ()
  }
  let attendees_json : Array[Json] = []
  for a in event.attendees {
    attendees_json.push(Json::string(a))
  }
  obj["attendees"] = Json::array(attendees_json)
  Json::object(obj)
}

///|
/// Handle JSON-RPC request
pub fn CalendarPlugin::handle_request(
  self : CalendarPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "create_event" => self.handle_create_event(request)
    "get_event" => self.handle_get_event(request)
    "update_event" => self.handle_update_event(request)
    "delete_event" => self.handle_delete_event(request)
    "list_events" => self.handle_list_events(request)
    "get_availability" => self.handle_get_availability(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn CalendarPlugin::handle_create_event(
  self : CalendarPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (title, start_time, end_time) = match request.params {
    Some(
      { "title": String(t), "start_time": String(s), "end_time": String(e), .. },
    ) => (t, s, e)
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing required parameters: title, start_time, end_time",
        id=request.id,
      )
  }
  let description = match request.params {
    Some({ "description": String(d), .. }) => d
    _ => ""
  }
  let location = match request.params {
    Some({ "location": String(l), .. }) => l
    _ => ""
  }
  let all_day = match request.params {
    Some({ "all_day": True, .. }) => true
    _ => false
  }
  let recurrence = match request.params {
    Some({ "recurrence": String(r), .. }) => Some(r)
    _ => None
  }
  let attendees : Array[String] = match request.params {
    Some({ "attendees": Array(a), .. }) => {
      let result : Array[String] = []
      for v in a {
        match v {
          String(s) => result.push(s)
          _ => ()
        }
      }
      result
    }
    _ => []
  }
  let reminder_minutes = match request.params {
    Some({ "reminder_minutes": Number(r, ..), .. }) => Some(r.to_int())
    _ => None
  }
  let calendar_id = match request.params {
    Some({ "calendar_id": String(c), .. }) => Some(c)
    _ => None
  }
  let event = self.create_event(
    title,
    start_time,
    end_time,
    description~,
    location~,
    all_day~,
    recurrence~,
    attendees~,
    reminder_minutes~,
    calendar_id~,
  )
  @interfaces.JsonRpcResponse::success(result=event_to_json(event), id=request.id)
}

///|
fn CalendarPlugin::handle_get_event(
  self : CalendarPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let event_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  match self.get_event(event_id) {
    Some(event) =>
      @interfaces.JsonRpcResponse::success(
        result=event_to_json(event),
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Event not found",
        id=request.id,
      )
  }
}

///|
fn CalendarPlugin::handle_update_event(
  self : CalendarPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let event_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  let title = match request.params {
    Some({ "title": String(t), .. }) => Some(t)
    _ => None
  }
  let description = match request.params {
    Some({ "description": String(d), .. }) => Some(d)
    _ => None
  }
  let start_time = match request.params {
    Some({ "start_time": String(s), .. }) => Some(s)
    _ => None
  }
  let end_time = match request.params {
    Some({ "end_time": String(e), .. }) => Some(e)
    _ => None
  }
  let location = match request.params {
    Some({ "location": String(l), .. }) => Some(l)
    _ => None
  }
  let updated = self.update_event(
    event_id, title~, description~, start_time~, end_time~, location~,
  )
  @interfaces.JsonRpcResponse::success(result={ "updated": updated }, id=request.id)
}

///|
fn CalendarPlugin::handle_delete_event(
  self : CalendarPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let event_id = match request.params {
    Some({ "id": String(i), .. }) => i
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'id' parameter",
        id=request.id,
      )
  }
  let deleted = self.delete_event(event_id)
  @interfaces.JsonRpcResponse::success(result={ "deleted": deleted }, id=request.id)
}

///|
fn CalendarPlugin::handle_list_events(
  self : CalendarPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let start_time = match request.params {
    Some({ "start_time": String(s), .. }) => Some(s)
    _ => None
  }
  let end_time = match request.params {
    Some({ "end_time": String(e), .. }) => Some(e)
    _ => None
  }
  let calendar_id = match request.params {
    Some({ "calendar_id": String(c), .. }) => Some(c)
    _ => None
  }
  let events = self.list_events(start_time~, end_time~, calendar_id~)
  let events_json : Array[Json] = []
  for event in events {
    events_json.push(event_to_json(event))
  }
  @interfaces.JsonRpcResponse::success(
    result={ "events": Json::array(events_json) },
    id=request.id,
  )
}

///|
fn CalendarPlugin::handle_get_availability(
  self : CalendarPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (start_time, end_time) = match request.params {
    Some({ "start_time": String(s), "end_time": String(e), .. }) => (s, e)
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'start_time' or 'end_time' parameter",
        id=request.id,
      )
  }
  let calendar_id = match request.params {
    Some({ "calendar_id": String(c), .. }) => Some(c)
    _ => None
  }
  let slots = self.get_availability(start_time, end_time, calendar_id~)
  let slots_json : Array[Json] = []
  for slot in slots {
    slots_json.push(
      { "start": slot.start, "end": slot.end, "busy": Json::boolean(slot.busy) },
    )
  }
  @interfaces.JsonRpcResponse::success(
    result={ "slots": Json::array(slots_json) },
    id=request.id,
  )
}
