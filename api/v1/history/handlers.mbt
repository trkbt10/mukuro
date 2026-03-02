///|
/// History API Handlers
/// HTTP handlers for /api/v1/history/* endpoints

///|
/// History state holder
pub(all) struct HistoryState {
  reader : &@interfaces.HistoryReader
  metadata_store : &@interfaces.HistoryMetadataStore?
}

///|
pub fn HistoryState::new(reader : &@interfaces.HistoryReader) -> HistoryState {
  { reader, metadata_store: None }
}

///|
/// メタデータストア付きでステートを作成
pub fn HistoryState::new_with_metadata_store(
  reader : &@interfaces.HistoryReader,
  metadata_store : &@interfaces.HistoryMetadataStore,
) -> HistoryState {
  { reader, metadata_store: Some(metadata_store) }
}

///|
/// Create history API handlers
pub fn create_history_handlers(state : HistoryState) -> @api.HistoryApiHandlers {
  {
    list_dates: @api.RouteHandler(fn(ctx) { handle_list_dates(state, ctx) }),
    list_sessions: @api.RouteHandler(fn(ctx) {
      handle_list_sessions(state, ctx)
    }),
    get_session: @api.RouteHandler(fn(ctx) { handle_get_session(state, ctx) }),
  }
}

///|
/// GET /history/dates - 日付一覧（セッション数付き）
fn handle_list_dates(
  state : HistoryState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let dates = state.reader.list_dates() catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to list history dates",
      )
  }
  // 各日付のセッション数をカウント
  let entries : Array[Json] = []
  for date in dates {
    let (year, month, day) = date
    let sessions = state.reader.list_sessions(year~, month~, day~) catch {
      _ => continue
    }
    entries.push(
      HistoryDateEntry::{ year, month, day, session_count: sessions.length() }.to_json(),
    )
  }
  // 逆時系列ソート（year, month, day の降順）
  entries.sort_by(fn(a, b) {
    let ay = json_int(a, "year")
    let by = json_int(b, "year")
    if ay != by {
      return by.compare(ay)
    }
    let am = json_int(a, "month")
    let bm = json_int(b, "month")
    if am != bm {
      return bm.compare(am)
    }
    let ad = json_int(a, "day")
    let bd = json_int(b, "day")
    bd.compare(ad)
  })
  @api.json_response(200, { "data": Json::array(entries) })
}

///|
fn json_int(j : Json, key : String) -> Int {
  match j {
    Object(obj) =>
      match obj.get(key) {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
    _ => 0
  }
}

///|
/// GET /history/sessions?year=&month=&day= - セッション一覧
fn handle_list_sessions(
  state : HistoryState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let year_str = match ctx.query.get("year") {
    Some(v) => v
    None =>
      return @api.error_response(
        400, "missing_param", "Query parameter 'year' is required",
      )
  }
  let month_str = match ctx.query.get("month") {
    Some(v) => v
    None =>
      return @api.error_response(
        400, "missing_param", "Query parameter 'month' is required",
      )
  }
  let day_str = match ctx.query.get("day") {
    Some(v) => v
    None =>
      return @api.error_response(
        400, "missing_param", "Query parameter 'day' is required",
      )
  }
  let year = @core_history.parse_int_string(year_str)
  let month = @core_history.parse_int_string(month_str)
  let day = @core_history.parse_int_string(day_str)
  match (year, month, day) {
    (Some(y), Some(m), Some(d)) => {
      // メタデータストアがあればそちらを使う
      match state.metadata_store {
        Some(store) => {
          let metas = store.list_by_date(year=y, month=m, day=d) catch {
            _ =>
              return @api.error_response(
                500, "internal_error", "Failed to list sessions from metadata",
              )
          }
          let summaries : Array[Json] = []
          for meta in metas {
            summaries.push(session_summary_from_metadata(meta).to_json())
          }
          return @api.json_response(200, { "data": Json::array(summaries) })
        }
        None => ()
      }
      // フォールバック: ファイルシステムから取得
      let filenames = state.reader.list_sessions(year=y, month=m, day=d) catch {
        _ =>
          return @api.error_response(
            500, "internal_error", "Failed to list sessions",
          )
      }
      let summaries : Array[Json] = []
      for filename in filenames {
        match @core_history.parse_history_filename(filename) {
          Some((channel, chat_id, epoch_secs)) =>
            summaries.push(
              HistorySessionSummary::{
                session_id: "\{channel}:\{chat_id}",
                channel,
                chat_id,
                filename,
                started_at: epoch_secs,
                record_count: 0,
                title: None,
                first_message: None,
                message_count: 0,
                user_message_count: 0,
                assistant_message_count: 0,
                tool_call_count: 0,
                model_name: None,
              }.to_json(),
            )
          None => ()
        }
      }
      @api.json_response(200, { "data": Json::array(summaries) })
    }
    _ =>
      @api.error_response(
        400, "invalid_param", "year, month, day must be valid integers",
      )
  }
}

///|
/// GET /history/sessions/{session_id} - セッション詳細
fn handle_get_session(
  state : HistoryState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // segments: ["history", "sessions", "{session_id}"]
  if ctx.segments.length() < 3 {
    return @api.error_response(400, "bad_request", "session_id is required")
  }
  let raw_session_id = ctx.segments[2]
  let session_id = @api.url_decode(raw_session_id)
  let records = state.reader.read_session(session_id~) catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to read session",
      )
  }
  let record_jsons : Array[Json] = []
  for record in records {
    record_jsons.push(history_record_to_json(record).to_json())
  }
  @api.json_response(200, {
    "data": {
      "session_id": session_id.to_json(),
      "records": Json::array(record_jsons),
    },
  })
}
