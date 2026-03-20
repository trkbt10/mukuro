///|
/// メモリ自動統合 — セッション終了時にメッセージをサマリー化して MEMORY.md に追記

///|
/// メッセージ配列からサマリーテキストを生成（簡易実装）
/// DigestService を呼ぶ代わりに、直接的なメッセージ要約を行う
pub fn summarize_messages_simple(
  messages : Array[@llm_types.ModelMessage],
) -> String {
  let buf = StringBuilder::new()
  let mut user_count = 0
  let mut assistant_count = 0
  let mut tool_count = 0
  let last_user_msg = StringBuilder::new()
  let last_assistant_msg = StringBuilder::new()
  for msg in messages {
    match msg {
      @llm_types.ModelMessage::User(content~, ..) => {
        user_count = user_count + 1
        last_user_msg.reset()
        // 最後の80文字を保持
        if content.length() > 80 {
          last_user_msg.write_string(content[:80].to_string())
          last_user_msg.write_string("...")
        } else {
          last_user_msg.write_string(content)
        }
      }
      @llm_types.ModelMessage::Assistant(content~, ..) => {
        assistant_count = assistant_count + 1
        last_assistant_msg.reset()
        if content.length() > 80 {
          last_assistant_msg.write_string(content[:80].to_string())
          last_assistant_msg.write_string("...")
        } else {
          last_assistant_msg.write_string(content)
        }
      }
      @llm_types.ModelMessage::ToolResult(..) => tool_count = tool_count + 1
      _ => ()
    }
  }
  buf.write_string("Session summary: \{user_count} user messages, \{assistant_count} assistant responses, \{tool_count} tool calls.")
  let user_text = last_user_msg.to_string()
  if user_text.length() > 0 {
    buf.write_string(" Last topic: \{user_text}")
  }
  buf.to_string()
}

///|
/// メッセージ閾値（この数以上のメッセージがあればサマリーを生成）
pub let consolidation_threshold : Int = 6

///|
/// セッション終了時にメモリ統合が必要かチェックし、サマリーを返す
pub fn maybe_consolidate(
  messages : Array[@llm_types.ModelMessage],
) -> String? {
  if messages.length() < consolidation_threshold {
    return None
  }
  Some(summarize_messages_simple(messages))
}
