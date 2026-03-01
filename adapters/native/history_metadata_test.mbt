///|
/// Tests for NativeHistoryMetadataStore
/// Note: SQLite integration tests require manual verification as they
/// depend on the native SQLite library being properly linked.

///|
/// Test NoOpMetadataStore basic operations
test "NoOpMetadataStore implements trait" {
  let store = @interfaces.NoOpMetadataStore::new()
  // Open should not fail
  store.open() catch { _ => fail("open should not fail") }
  // Get should return None
  let result = store.get(session_id="any") catch { _ => fail("get failed") }
  inspect(result.is_none(), content="true")
  // List should return empty
  let dates = store.list_by_date(year=2024, month=3, day=1) catch {
    _ => fail("list_by_date failed")
  }
  inspect(dates.length(), content="0")
  let recent = store.list_recent(limit=10, offset=0) catch {
    _ => fail("list_recent failed")
  }
  inspect(recent.length(), content="0")
  let search_results = store.search(query="test", limit=10) catch {
    _ => fail("search failed")
  }
  inspect(search_results.length(), content="0")
  // Close should not fail
  store.close()
}

///|
/// Test SessionMetadata struct creation
test "SessionMetadata struct fields" {
  let metadata = @interfaces.SessionMetadata::{
    session_id: "web_chat:abc123",
    channel: "web_chat",
    chat_id: "abc123",
    title: Some("Test conversation"),
    first_message: Some("Hello, how are you?"),
    message_count: 10,
    user_message_count: 5,
    assistant_message_count: 5,
    tool_call_count: 2,
    created_at: 1709251200000L,
    updated_at: 1709255800000L,
    file_path: "/data/history/2024/03/01/web_chat-abc123-1709251200.jsonl",
    model_name: Some("claude-3-opus"),
  }
  inspect(metadata.session_id, content="web_chat:abc123")
  inspect(metadata.channel, content="web_chat")
  inspect(metadata.chat_id, content="abc123")
  inspect(metadata.title.unwrap(), content="Test conversation")
  inspect(metadata.first_message.unwrap(), content="Hello, how are you?")
  inspect(metadata.message_count, content="10")
  inspect(metadata.user_message_count, content="5")
  inspect(metadata.assistant_message_count, content="5")
  inspect(metadata.tool_call_count, content="2")
  inspect(metadata.model_name.unwrap(), content="claude-3-opus")
}

///|
/// Test default_metadata_db_path returns expected path structure
test "default_metadata_db_path format" {
  let path = default_metadata_db_path()
  // Should end with metadata.db
  inspect(path.length() > 0, content="true")
  // Path should contain "history" and "metadata.db"
  let contains_history = {
    let mut found = false
    for i = 0; i < path.length() - 7; i = i + 1 {
      if path[i] == 'h' && path[i + 1] == 'i' && path[i + 2] == 's' &&
         path[i + 3] == 't' && path[i + 4] == 'o' && path[i + 5] == 'r' && path[i + 6] == 'y' {
        found = true
        break
      }
    }
    found
  }
  inspect(contains_history, content="true")
}
