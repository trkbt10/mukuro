///|
/// セッション復元ロジック
/// JSONL の HistoryRecord 配列から Session を再構築する pure 関数

///|
/// HistoryRecord 配列から Session を再構築
pub fn reconstruct_session_from_history(
  key : @types.SessionKey,
  records : Array[@interfaces.HistoryRecord],
) -> @types.Session {
  let mut created_at = 0L
  let mut last_active_at = 0L
  let history : Array[@llm_types.ModelMessage] = []
  // AssistantMessage with tool_calls の処理状態
  let pending_tool_calls : Array[@llm_types.ToolCallRequest] = []
  let mut pending_assistant_index : Int = -1
  let mut pending_assistant_content : String = ""

  for record in records {
    if created_at == 0L {
      created_at = record.timestamp
    }
    if record.timestamp > last_active_at {
      last_active_at = record.timestamp
    }

    match record.record_type {
      @interfaces.HistoryRecordType::UserMessage => {
        // 前の AssistantMessage に tool_calls を反映
        finalize_pending_assistant(
          history, pending_tool_calls, pending_assistant_index, pending_assistant_content,
        )
        pending_assistant_index = -1
        pending_tool_calls.clear()

        let content = extract_payload_content(record.payload)
        let name = extract_payload_name(record.payload)
        history.push(@llm_types.ModelMessage::User(content~, name~))
      }
      @interfaces.HistoryRecordType::AssistantMessage => {
        // 前の AssistantMessage に tool_calls を反映
        finalize_pending_assistant(
          history, pending_tool_calls, pending_assistant_index, pending_assistant_content,
        )
        pending_tool_calls.clear()

        let content = extract_payload_content(record.payload)
        let has_tool_calls = extract_payload_has_tool_calls(record.payload)
        if has_tool_calls {
          // tool_calls は後続の ToolCall レコードから取得するので、一時的に None で追加
          pending_assistant_index = history.length()
          pending_assistant_content = content
          history.push(
            @llm_types.ModelMessage::Assistant(content~, tool_calls=None),
          )
        } else {
          pending_assistant_index = -1
          history.push(
            @llm_types.ModelMessage::Assistant(content~, tool_calls=None),
          )
        }
      }
      @interfaces.HistoryRecordType::ToolCall => {
        // ToolCall を蓄積（直前の AssistantMessage に関連付け）
        let tool_call = extract_tool_call_payload(record.payload)
        pending_tool_calls.push(tool_call)
      }
      @interfaces.HistoryRecordType::ToolResult => {
        // ToolResult の前に pending の AssistantMessage を確定
        finalize_pending_assistant(
          history, pending_tool_calls, pending_assistant_index, pending_assistant_content,
        )
        pending_assistant_index = -1
        pending_tool_calls.clear()

        let (call_id, content) = extract_tool_result_payload(record.payload)
        history.push(
          @llm_types.ModelMessage::ToolResult(tool_call_id=call_id, content~),
        )
      }
      _ => () // SessionMeta, Error は直接 history に入れない
    }
  }

  // ループ終了後、未処理の AssistantMessage があれば確定
  finalize_pending_assistant(
    history, pending_tool_calls, pending_assistant_index, pending_assistant_content,
  )

  // Session を作成し、復元したメッセージを追加
  {
    key,
    history,
    state: @types.SessionState::Active,
    created_at,
    last_active_at,
    metadata: {},
  }
}

///|
/// 保留中の AssistantMessage に tool_calls を反映
fn finalize_pending_assistant(
  history : Array[@llm_types.ModelMessage],
  pending_tool_calls : Array[@llm_types.ToolCallRequest],
  pending_assistant_index : Int,
  pending_assistant_content : String,
) -> Unit {
  if pending_assistant_index >= 0 && pending_tool_calls.length() > 0 {
    let tool_calls = pending_tool_calls.copy()
    history[pending_assistant_index] = @llm_types.ModelMessage::Assistant(
      content=pending_assistant_content,
      tool_calls=Some(tool_calls),
    )
  }
}

///|
/// payload から content を抽出
pub fn extract_payload_content(payload : Json) -> String {
  match payload {
    Object(obj) =>
      match obj.get("content") {
        Some(String(s)) => s
        _ => ""
      }
    String(s) => s
    _ => ""
  }
}

///|
/// payload から name を抽出
pub fn extract_payload_name(payload : Json) -> String? {
  match payload {
    Object(obj) =>
      match obj.get("name") {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// payload から ToolResult の情報を抽出
pub fn extract_tool_result_payload(payload : Json) -> (String, String) {
  match payload {
    Object(obj) => {
      let call_id = match obj.get("call_id") {
        Some(String(s)) => s
        _ => ""
      }
      let content = match obj.get("content") {
        Some(String(s)) => s
        _ => ""
      }
      (call_id, content)
    }
    _ => ("", "")
  }
}

///|
/// payload から has_tool_calls を抽出
pub fn extract_payload_has_tool_calls(payload : Json) -> Bool {
  match payload {
    Object(obj) =>
      match obj.get("has_tool_calls") {
        Some(True) => true
        _ => false
      }
    _ => false
  }
}

///|
/// payload から ToolCall を抽出
pub fn extract_tool_call_payload(payload : Json) -> @llm_types.ToolCallRequest {
  match payload {
    Object(obj) => {
      let call_id = match obj.get("call_id") {
        Some(String(s)) => s
        _ => ""
      }
      let tool_name = match obj.get("tool_name") {
        Some(String(s)) => s
        _ => ""
      }
      let arguments = match obj.get("arguments") {
        Some(args) => args
        _ => Json::object({})
      }
      {
        id: call_id,
        name: tool_name,
        arguments,
        kind: @llm_types.ToolCallKind::Function,
      }
    }
    _ =>
      {
        id: "",
        name: "",
        arguments: Json::object({}),
        kind: @llm_types.ToolCallKind::Function,
      }
  }
}
