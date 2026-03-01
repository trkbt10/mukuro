///|
/// WebSocket Chat Handler 統合テスト
/// ChatWsHandler と agent loop の履歴記録統合をテスト

// ============================================================
// SpyHistoryRecorder - 記録を追跡するテスト用実装
// ============================================================

///|
struct SpyHistoryRecorder {
  mut open_count : Int
  mut close_count : Int
  mut session_id : String
  records : Array[@interfaces.HistoryRecord]
  mut is_open : Bool
}

///|
fn SpyHistoryRecorder::new() -> SpyHistoryRecorder {
  {
    open_count: 0,
    close_count: 0,
    session_id: "",
    records: [],
    is_open: false,
  }
}

///|
impl @interfaces.HistoryRecorder for SpyHistoryRecorder with open_session(
  self,
  session_id~,
  timestamp~,
) -> Bool raise @interfaces.HistoryError {
  ignore(timestamp)
  self.open_count += 1
  self.session_id = session_id
  self.is_open = true
  true
}

///|
impl @interfaces.HistoryRecorder for SpyHistoryRecorder with record(
  self,
  record~,
) -> Unit raise @interfaces.HistoryError {
  if not(self.is_open) {
    raise @interfaces.HistoryError::IoError("Recorder not open")
  }
  self.records.push(record)
}

///|
impl @interfaces.HistoryRecorder for SpyHistoryRecorder with close(self) -> Unit raise @interfaces.HistoryError {
  self.close_count += 1
  self.is_open = false
}

// ============================================================
// テスト: ChatWsHandler の履歴記録フロー
// ============================================================

test "history recording flow: open_session then record via trait object" {
  // ChatWsHandler と同じフローをシミュレート
  let spy = SpyHistoryRecorder::new()

  // 1. trait object として保持（ChatWsHandler.history_recorder と同じ）
  let history_recorder : &@interfaces.HistoryRecorder = spy

  // 2. safe_open_session を呼ぶ（ChatWsHandler.handle_connection と同じ）
  let session_id = "web_chat:test-chat-id"
  let timestamp = 1772330000000L
  let is_new = @agent.safe_open_session(
    Some(history_recorder),
    session_id,
    timestamp,
  )
  assert_eq(is_new, Some(true))
  assert_eq(spy.open_count, 1)
  assert_eq(spy.session_id, session_id)
  assert_true(spy.is_open, msg="Recorder should be open after open_session")

  // 3. record_session_meta を呼ぶ
  @agent.record_session_meta(
    Some(history_recorder),
    None,
    timestamp,
    session_id,
    Json::object({ "channel": Json::string("web_chat") }),
  )
  assert_eq(spy.records.length(), 1)
  assert_eq(spy.records[0].record_type, @interfaces.HistoryRecordType::SessionMeta)

  // 4. safe_close を呼ぶ
  @agent.safe_close(Some(history_recorder))
  assert_eq(spy.close_count, 1)
  assert_false(spy.is_open, msg="Recorder should be closed after close")
}

test "history recording: record fails if open_session not called" {
  let spy = SpyHistoryRecorder::new()
  let history_recorder : &@interfaces.HistoryRecorder = spy

  // open_session を呼ばずに record_session_meta を呼ぶ
  // safe_record は例外を無視するので、レコードは追加されないはず
  @agent.record_session_meta(
    Some(history_recorder),
    None,
    1000L,
    "test:session",
    Json::object({}),
  )

  // レコードは追加されていないはず（recorder が開いていないため）
  assert_eq(spy.records.length(), 0)
}

test "history recording: multiple records after open_session" {
  let spy = SpyHistoryRecorder::new()
  let history_recorder : &@interfaces.HistoryRecorder = spy
  let session_id = "web_chat:multi-record-test"
  let timestamp = 1772330000000L

  // open_session
  let _ = @agent.safe_open_session(Some(history_recorder), session_id, timestamp)

  // 複数のレコードを記録
  @agent.record_session_meta(
    Some(history_recorder),
    None,
    timestamp,
    session_id,
    Json::object({ "model": Json::string("test-model") }),
  )

  // Note: record_user_message は package-private なので直接呼べない
  // 代わりに safe_record 経由で検証するか、agent loop を通すテストが必要

  assert_eq(spy.records.length(), 1)
  assert_eq(spy.records[0].record_type, @interfaces.HistoryRecordType::SessionMeta)
}

// ============================================================
// テスト: NativeHistoryRecorder を使った実際のファイル書き込み
// ============================================================

test "NativeHistoryRecorder: ChatWsHandler flow simulation" {
  // 実際の NativeHistoryRecorder を使ってフローをテスト
  let base_dir = "/tmp/mukuro_test_ws_handler_\{@native.c_time()}"
  let recorder = @native.NativeHistoryRecorder::new(base_dir~)

  // ChatWsHandler と同じように trait object として保持
  let history_recorder : &@interfaces.HistoryRecorder = recorder

  let session_id = "web_chat:integration-test-\{@native.c_time()}"
  let timestamp = 1772330000000L

  // 1. open_session (ChatWsHandler.handle_connection)
  let is_new = @agent.safe_open_session(
    Some(history_recorder),
    session_id,
    timestamp,
  )
  assert_eq(is_new, Some(true))

  // 2. record_session_meta (ChatWsHandler.handle_connection)
  @agent.record_session_meta(
    Some(history_recorder),
    None,
    timestamp,
    session_id,
    Json::object({
      "channel": Json::string("web_chat"),
      "model": Json::string("test-model"),
    }),
  )

  // 3. close (ChatWsHandler.handle_connection end)
  @agent.safe_close(Some(history_recorder))

  // 4. 読み込んで検証
  let reader = @native.NativeHistoryReader::new(base_dir~)
  let records = reader.read_session(session_id~) catch {
    _ => fail("read_session should not fail")
  }

  // 少なくとも SessionMeta が記録されているはず
  assert_true(records.length() >= 1, msg="Should have at least 1 record")
  assert_eq(records[0].record_type, @interfaces.HistoryRecordType::SessionMeta)
}

// ============================================================
// テスト: create_session_history_recorder() を使った実際のフロー
// プロダクションコードと同じパスを通る
// ============================================================

test "create_session_history_recorder: returned trait object should work" {
  // プロダクションコードと同じ create_session_history_recorder() を使う
  let history_recorder = create_session_history_recorder()

  let session_id = "web_chat:create-recorder-test-\{@native.c_time()}"
  let timestamp = 1772330000000L

  // 1. open_session
  let is_new = @agent.safe_open_session(
    Some(history_recorder),
    session_id,
    timestamp,
  )
  assert_eq(is_new, Some(true), msg="open_session should return Some(true)")

  // 2. record_session_meta
  @agent.record_session_meta(
    Some(history_recorder),
    None,
    timestamp,
    session_id,
    Json::object({
      "channel": Json::string("web_chat"),
      "test": Json::string("create_session_history_recorder"),
    }),
  )

  // 3. close
  @agent.safe_close(Some(history_recorder))

  // 4. 読み込んで検証（@config.data_dir() を使って正しいパスから読む）
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    _ => fail("read_session should not fail")
  }

  // SessionMeta が記録されているはず
  assert_true(records.length() >= 1, msg="Should have at least 1 record from create_session_history_recorder")
  assert_eq(records[0].record_type, @interfaces.HistoryRecordType::SessionMeta)
}

// 構造体に trait object を格納した場合のテスト用ラッパー
struct TraitObjectHolder {
  recorder : &@interfaces.HistoryRecorder
}

test "trait object in struct field: mutable state should persist" {
  // SpyRecorder を struct フィールドに格納して状態が保持されるか確認
  let spy = SpyHistoryRecorder::new()
  let holder : TraitObjectHolder = { recorder: spy }

  let session_id = "test:holder-test"
  let timestamp = 1000L

  // holder.recorder 経由で open_session
  let is_new = @agent.safe_open_session(
    Some(holder.recorder),
    session_id,
    timestamp,
  )
  assert_eq(is_new, Some(true), msg="open_session via holder should return Some(true)")

  // spy の状態を確認
  assert_eq(spy.open_count, 1, msg="spy.open_count should be 1")
  assert_true(spy.is_open, msg="spy.is_open should be true")

  // record via holder
  @agent.record_session_meta(
    Some(holder.recorder),
    None,
    timestamp,
    session_id,
    Json::object({}),
  )
  assert_eq(spy.records.length(), 1, msg="spy.records should have 1 record")
}

test "ChatWsHandler::new: history_recorder should be usable" {
  // 実際の ChatWsHandler::new() を使う
  let handler = ChatWsHandler::new()

  // テスト用にユニークなセッションIDを生成（c_time() を含める）
  let unique_suffix = @native.c_time()
  let session_id = "web_chat:\{handler.chat_id}-test-\{unique_suffix}"
  let timestamp = 1772330000000L

  // 1. handler.history_recorder を使って open_session
  let is_new = @agent.safe_open_session(
    Some(handler.history_recorder),
    session_id,
    timestamp,
  )
  // Debug: 実際の戻り値を確認
  match is_new {
    Some(true) => () // 期待通り
    Some(false) =>
      fail(
        "open_session returned Some(false) - session_id=\{session_id}, handler.chat_id=\{handler.chat_id}",
      )
    None => fail("open_session returned None - an error was caught by safe_open_session")
  }

  // 2. record_session_meta
  @agent.record_session_meta(
    Some(handler.history_recorder),
    None,
    timestamp,
    session_id,
    Json::object({
      "channel": Json::string("web_chat"),
      "chat_id": Json::string(handler.chat_id),
    }),
  )

  // 3. close
  @agent.safe_close(Some(handler.history_recorder))

  // 4. 読み込んで検証
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    _ => fail("read_session should not fail")
  }

  assert_true(records.length() >= 1, msg="Should have at least 1 record")
  assert_eq(records[0].record_type, @interfaces.HistoryRecordType::SessionMeta)
}

// ============================================================
// テスト: handle_connection の完全なフローシミュレーション
// ============================================================

test "handle_connection flow: complete session lifecycle" {
  // handle_connection と同じフローをシミュレート
  let unique_suffix = @native.c_time()
  let handler = ChatWsHandler::new()
  let session_id = "web_chat:\{handler.chat_id}-lifecycle-\{unique_suffix}"
  let timestamp = 1772330000000L

  // 1. create_session (handle_connection の最初で呼ばれる)
  handler.create_session()

  // 2. safe_open_session (handle_connection で呼ばれる)
  let is_new_session = @agent.safe_open_session(
    Some(handler.history_recorder),
    session_id,
    timestamp,
  )
  match is_new_session {
    Some(true) => () // 期待通り
    Some(false) => fail("lifecycle: open_session returned Some(false)")
    None => fail("lifecycle: open_session returned None")
  }

  // 3. record_session_meta (is_new_session == Some(true) の場合)
  if is_new_session == Some(true) {
    @agent.record_session_meta(
      Some(handler.history_recorder),
      Some(global_clock),
      timestamp,
      session_id,
      Json::object({
        "channel": Json::string("web_chat"),
        "chat_id": Json::string(handler.chat_id),
      }),
    )
  }

  // 4. handle_send のシミュレーション
  // Note: 実際の handle_inbound_with_agent_loop_async は呼ばない
  // agent loop 内での record_user_message, record_assistant_message を直接呼ぶ

  // 5. safe_close
  @agent.safe_close(Some(handler.history_recorder))

  // 6. 読み込んで検証
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    _ => fail("read_session should not fail")
  }

  assert_true(records.length() >= 1, msg="lifecycle: Should have at least 1 record")
  assert_eq(records[0].record_type, @interfaces.HistoryRecordType::SessionMeta)
}

// ============================================================
// テスト: ファイルシステム上にファイルが作成されていることを確認
// ============================================================

test "file creation verification: history file should exist after recording" {
  let unique_suffix = @native.c_time()
  let recorder = @native.NativeHistoryRecorder::new(base_dir=@config.data_dir())
  let history_recorder : &@interfaces.HistoryRecorder = recorder
  let session_id = "web_chat:file-verify-test-\{unique_suffix}"
  let timestamp = 1772330000000L

  // open_session
  let is_new = @agent.safe_open_session(
    Some(history_recorder),
    session_id,
    timestamp,
  )
  assert_eq(is_new, Some(true), msg="file-verify: open_session should return Some(true)")

  // record_session_meta
  @agent.record_session_meta(
    Some(history_recorder),
    None,
    timestamp,
    session_id,
    Json::object({ "test": Json::string("file-verify") }),
  )

  // close
  @agent.safe_close(Some(history_recorder))

  // reader で読めることを確認（ファイルが作成されていれば読める）
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    _ => fail("read_session should not fail - file may not exist")
  }
  assert_eq(records.length(), 1, msg="file-verify: Should have exactly 1 record")
}

// ============================================================
// テスト: handle_send の実際のフローシミュレーション
// ============================================================

test "handle_send simulation: agent loop should record via passed history_recorder" {
  // 実際の ChatWsHandler と同じフローをシミュレート
  let unique_suffix = @native.c_time()
  let handler = ChatWsHandler::new()
  let session_id = "web_chat:\{handler.chat_id}-send-sim-\{unique_suffix}"
  let timestamp = 1772330000000L

  // 1. handle_connection で行われる処理:
  //    - safe_open_session
  //    - record_session_meta
  let is_new = @agent.safe_open_session(
    Some(handler.history_recorder),
    session_id,
    timestamp,
  )
  assert_eq(is_new, Some(true), msg="send-sim: open should return Some(true)")

  @agent.record_session_meta(
    Some(handler.history_recorder),
    Some(global_clock),
    timestamp,
    session_id,
    Json::object({
      "channel": Json::string("web_chat"),
      "chat_id": Json::string(handler.chat_id),
    }),
  )

  // 2. handle_send の処理をシミュレート:
  //    - InboundEnvelope を作成
  //    - handle_inbound_with_agent_loop_async を呼ぶ
  //    (実際に呼ぶと外部 API を叩くので、ここでは record_user_message だけテスト)

  // agent loop が内部で行う処理をシミュレート
  // run_agent_loop_async の line 607 相当 - record_user_message は内部関数なので
  // 直接 recorder.record() を呼ぶ
  let user_record : @interfaces.HistoryRecord = {
    timestamp: timestamp + 1000L,
    session_id,
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({ "content": Json::string("test message from user") }),
  }
  handler.history_recorder.record(record=user_record) catch {
    _ => fail("record should not fail")
  }

  // 3. safe_close
  @agent.safe_close(Some(handler.history_recorder))

  // 4. 読み込んで検証
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    _ => fail("read_session should not fail")
  }

  // SessionMeta + UserMessage = 2 records
  assert_eq(records.length(), 2, msg="send-sim: Should have 2 records (SessionMeta + UserMessage)")
  assert_eq(records[0].record_type, @interfaces.HistoryRecordType::SessionMeta)
  assert_eq(records[1].record_type, @interfaces.HistoryRecordType::UserMessage)
}

// ============================================================
// テスト: エラーケースの確認
// ============================================================

test "error case: record without open_session should fail silently" {
  // open_session を呼ばずに record を呼ぶ
  let unique_suffix = @native.c_time()
  let recorder = @native.NativeHistoryRecorder::new(base_dir=@config.data_dir())
  let session_id = "web_chat:no-open-test-\{unique_suffix}"
  let timestamp = 1772330000000L

  // open_session を呼ばずに record を呼ぶ
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({ "content": Json::string("should not be recorded") }),
  }

  // record should raise an error (file not open)
  let mut error_caught = false
  recorder.record(record~) catch {
    @interfaces.HistoryError::IoError(_) => error_caught = true
    _ => error_caught = true
  }

  // record should fail because open_session was not called
  assert_true(error_caught, msg="record without open_session should fail")
}

test "data_dir verification: check actual path" {
  // @config.data_dir() の値を確認
  let data_dir = @config.data_dir()

  // data_dir が空でないことを確認
  assert_true(data_dir.length() > 0, msg="data_dir should not be empty")

  // data_dir が期待されるパスパターンであることを確認
  // macOS: ~/Library/Application Support/mukuro/
  // または --local フラグ時: .mukuro
  let is_valid_path = data_dir.has_suffix("/mukuro") || data_dir == ".mukuro"
  assert_true(
    is_valid_path,
    msg="data_dir should be valid path, got: \{data_dir}",
  )
}

// ============================================================
// エラーケースの検証テスト
// ============================================================

test "error case: NotInitialized error has clear message" {
  let recorder = @native.NativeHistoryRecorder::new(base_dir=@config.data_dir())
  let record : @interfaces.HistoryRecord = {
    timestamp: 1000L,
    session_id: "test:not-init",
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({}),
  }

  let mut error_msg = ""
  let mut is_not_initialized = false
  recorder.record(record~) catch {
    @interfaces.HistoryError::NotInitialized => {
      is_not_initialized = true
      error_msg = "\{@interfaces.HistoryError::NotInitialized}"
    }
    e => error_msg = "\{e}"
  }

  assert_true(is_not_initialized, msg="Should raise NotInitialized error")
  assert_true(
    error_msg.contains("NotInitialized"),
    msg="NotInitialized should have clear message, got: \{error_msg}",
  )
}

test "error case: FileOpenFailed has path and reason" {
  // 存在しないディレクトリに書き込もうとする
  let recorder = @native.NativeHistoryRecorder::new(
    base_dir="/nonexistent/path/that/should/not/exist",
  )
  let session_id = "test:file-open-fail"
  let timestamp = 1772330000000L

  let mut error_caught = false
  let mut error_type = ""
  let _ = try {
    let _ = recorder.open_session(session_id~, timestamp~)
    error_type = "no_error"
  } catch {
    @interfaces.HistoryError::DirectoryCreationFailed(_) => {
      error_caught = true
      error_type = "DirectoryCreationFailed"
    }
    @interfaces.HistoryError::FileOpenFailed(..) => {
      error_caught = true
      error_type = "FileOpenFailed"
    }
    e => {
      error_caught = true
      error_type = "\{e}"
    }
  }

  // ディレクトリ作成失敗か、ファイルオープン失敗のどちらか
  assert_true(error_caught, msg="Should catch an error")
  assert_true(
    error_type == "DirectoryCreationFailed" ||
    error_type == "FileOpenFailed",
    msg="Should fail with DirectoryCreationFailed or FileOpenFailed, got: \{error_type}",
  )
}

// ============================================================
// 統合テスト: 実際のファイル作成を検証
// ============================================================

test "integration: verify file is actually created on disk" {
  // テスト用の一時ディレクトリを使用
  let test_dir = "/tmp/mukuro_integration_test_\{@native.c_time()}"
  let recorder = @native.NativeHistoryRecorder::new(base_dir=test_dir)

  let session_id = "web_chat:integration-verify-\{@native.c_time()}"
  let timestamp = @native.c_time() * 1000L // 現在時刻をミリ秒で

  // Step 1: open_session
  let is_new = recorder.open_session(session_id~, timestamp~) catch {
    e => {
      fail("open_session failed: \{e}")
    }
  }
  assert_true(is_new, msg="Should be a new session")

  // Step 2: record
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "test": Json::string("integration") }),
  }
  recorder.record(record~) catch {
    e => fail("record failed: \{e}")
  }

  // Step 3: close
  recorder.close() catch {
    e => fail("close failed: \{e}")
  }

  // Step 4: ファイルが実際に存在するか確認
  let reader = @native.NativeHistoryReader::new(base_dir=test_dir)
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }

  assert_eq(records.length(), 1, msg="Should have 1 record on disk")
  assert_eq(records[0].record_type, @interfaces.HistoryRecordType::SessionMeta)
}

test "integration: verify handle_connection creates files in data_dir" {
  // ChatWsHandler と同じフローを検証
  let handler = ChatWsHandler::new()
  let session_id = "web_chat:\{handler.chat_id}"
  let timestamp = @native.c_time() * 1000L

  // Step 1: open_session (handle_connection がやること)
  let is_new = handler.history_recorder.open_session(session_id~, timestamp~) catch {
    e => {
      fail("handle_connection: open_session failed: \{e}")
    }
  }

  // Step 2: record SessionMeta
  if is_new {
    let meta_record : @interfaces.HistoryRecord = {
      timestamp,
      session_id,
      record_type: @interfaces.HistoryRecordType::SessionMeta,
      payload: Json::object({
        "channel": Json::string("web_chat"),
        "chat_id": Json::string(handler.chat_id),
      }),
    }
    handler.history_recorder.record(record=meta_record) catch {
      e => fail("handle_connection: record failed: \{e}")
    }
  }

  // Step 3: close
  handler.history_recorder.close() catch {
    e => fail("handle_connection: close failed: \{e}")
  }

  // Step 4: ファイルが @config.data_dir() に存在するか確認
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }

  // 少なくとも SessionMeta が記録されているはず
  assert_true(
    records.length() >= 1,
    msg="Should have at least 1 record in data_dir, got \{records.length()}",
  )
}

test "integration: verify create_session_history_recorder works" {
  // create_session_history_recorder() の戻り値を直接テスト
  let recorder = create_session_history_recorder()
  let session_id = "web_chat:create-recorder-verify-\{@native.c_time()}"
  let timestamp = @native.c_time() * 1000L

  // open_session
  let is_new = recorder.open_session(session_id~, timestamp~) catch {
    e => fail("create_session_history_recorder: open_session failed: \{e}")
  }
  assert_true(is_new, msg="Should be new session")

  // record
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "source": Json::string("create_session_history_recorder") }),
  }
  recorder.record(record~) catch {
    e => fail("create_session_history_recorder: record failed: \{e}")
  }

  // close
  recorder.close() catch {
    e => fail("create_session_history_recorder: close failed: \{e}")
  }

  // verify file exists
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 1, msg="Should have 1 record")
}

test "debug: check data_dir value and file creation" {
  // data_dir の値を出力し、ファイル作成をステップバイステップで検証
  let data_dir = @config.data_dir()

  // 一意のセッションID
  let unique_id = @native.c_time()
  let session_id = "web_chat:debug-\{unique_id}"
  let timestamp = unique_id * 1000L

  // recorder を作成
  let recorder = @native.NativeHistoryRecorder::new(base_dir=data_dir)

  // open_session - これがディレクトリを作成し、ファイルを開く
  let is_new = recorder.open_session(session_id~, timestamp~) catch {
    @interfaces.HistoryError::FileOpenFailed(path~, reason~) =>
      fail("FileOpenFailed: path=\{path}, reason=\{reason}")
    @interfaces.HistoryError::DirectoryCreationFailed(path) =>
      fail("DirectoryCreationFailed: \{path}")
    e => fail("open_session failed: \{e}")
  }

  // record
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "debug": Json::string("test") }),
  }
  recorder.record(record~) catch {
    @interfaces.HistoryError::NotInitialized => fail("NotInitialized")
    @interfaces.HistoryError::WriteFailed(expected~, actual~) =>
      fail("WriteFailed: expected=\{expected}, actual=\{actual}")
    e => fail("record failed: \{e}")
  }

  // close
  recorder.close() catch { _ => () }

  // verify
  let reader = @native.NativeHistoryReader::new(base_dir=data_dir)
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }

  assert_true(
    records.length() == 1,
    msg="debug: data_dir=\{data_dir}, is_new=\{is_new}, records=\{records.length()}",
  )
}

test "error case: Show trait works for all error variants" {
  // 各エラーバリアントが Show trait で正しく出力されるか確認
  let io_err : @interfaces.HistoryError = @interfaces.HistoryError::IoError(
    "test io error",
  )
  assert_true("\{io_err}".has_prefix("IoError:"), msg="IoError Show works")

  let dir_err : @interfaces.HistoryError = @interfaces.HistoryError::DirectoryCreationFailed(
    "/some/path",
  )
  assert_true(
    "\{dir_err}".has_prefix("DirectoryCreationFailed:"),
    msg="DirectoryCreationFailed Show works",
  )

  let perm_err : @interfaces.HistoryError = @interfaces.HistoryError::PermissionDenied(
    "/protected/path",
  )
  assert_true(
    "\{perm_err}".has_prefix("PermissionDenied:"),
    msg="PermissionDenied Show works",
  )

  let file_err : @interfaces.HistoryError = @interfaces.HistoryError::FileOpenFailed(
    path="/some/file",
    reason="permission denied",
  )
  assert_true(
    "\{file_err}".has_prefix("FileOpenFailed:"),
    msg="FileOpenFailed Show works",
  )

  let write_err : @interfaces.HistoryError = @interfaces.HistoryError::WriteFailed(
    expected=100,
    actual=50,
  )
  assert_true(
    "\{write_err}".has_prefix("WriteFailed:"),
    msg="WriteFailed Show works",
  )

  let not_init : @interfaces.HistoryError = @interfaces.HistoryError::NotInitialized
  assert_true(
    "\{not_init}".has_prefix("NotInitialized:"),
    msg="NotInitialized Show works",
  )
}

// ============================================================
// ファイル存在確認テスト - 実際にディスクにファイルが作成されるか検証
// ============================================================

test "file existence: verify file is created on disk after record" {
  let data_dir = @config.data_dir()
  let unique_id = @native.c_time()
  let session_id = "web_chat:file-exist-test-\{unique_id}"
  let timestamp = unique_id * 1000L

  let recorder = @native.NativeHistoryRecorder::new(base_dir=data_dir)

  // open_session
  let is_new = recorder.open_session(session_id~, timestamp~) catch {
    e => fail("open_session failed: \{e}")
  }
  assert_true(is_new, msg="Should be new session")

  // record
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "test": Json::string("file_exist") }),
  }
  recorder.record(record~) catch {
    e => fail("record failed: \{e}")
  }

  // close to ensure flush
  recorder.close() catch { _ => () }

  // 実際のファイルパスを計算
  let epoch_secs = timestamp / 1000L
  let (year, month, day) = @native.native_epoch_to_date(epoch_secs) catch {
    _ => fail("native_epoch_to_date failed")
  }
  let dir_path = @history.history_dir_for_date(data_dir, year, month, day)
  let (channel, chat_id) = @history.split_session_id(session_id)
  let file_path = @history.history_file_path(
    data_dir, channel, chat_id, year, month, day, epoch_secs,
  )

  // ディレクトリ存在確認
  let dir_exists = @native.c_file_exists_bytes(@native.string_to_utf8_cstring(dir_path)) == 1
  assert_true(dir_exists, msg="Directory should exist: \{dir_path}")

  // ファイル存在確認
  let file_exists = @native.c_file_exists_bytes(@native.string_to_utf8_cstring(file_path)) == 1
  assert_true(file_exists, msg="File should exist: \{file_path}")

  // ファイル内容確認
  let content = @native.native_read_file_text(file_path) catch {
    _ => fail("Failed to read file: \{file_path}")
  }
  assert_true(content.length() > 0, msg="File should have content, got empty")
  assert_true(
    content.contains("session_meta"),
    msg="File should contain session_meta record",
  )
}

// ============================================================
// get_timestamp_ms() のテスト - プロダクションコードの正確な動作を検証
// ============================================================

test "get_timestamp_ms: should return valid Int64 timestamp" {
  // プロダクションと同じ計算をテスト
  let c_time_result = @native.c_time()
  let timestamp_with_L = c_time_result * 1000L  // テストで使用されている形式
  let timestamp_without_L = c_time_result * 1000  // プロダクションで使用されている形式

  // 両者が同じ値か確認
  assert_eq(
    timestamp_with_L,
    timestamp_without_L,
    msg="c_time * 1000L should equal c_time * 1000",
  )

  // 妥当な範囲か確認（2026年のタイムスタンプは約1.77e12）
  assert_true(
    timestamp_without_L > 1700000000000L,
    msg="Timestamp should be > 1.7e12 (2023+)",
  )
  assert_true(
    timestamp_without_L < 2000000000000L,
    msg="Timestamp should be < 2.0e12 (2033-)",
  )
}

test "production flow: ChatWsHandler with actual get_timestamp_ms" {
  // ChatWsHandler と同じフローを再現
  let handler = ChatWsHandler::new()
  // 一意のセッションIDを生成（テストの決定論的UUIDを回避）
  let unique_suffix = @native.c_time()
  let session_id = "web_chat:prod-flow-test-\{unique_suffix}"

  // プロダクションと同じ get_timestamp_ms 相当の計算
  let timestamp = @native.c_time() * 1000  // L なし（プロダクションと同じ）

  // open_session
  let is_new = handler.history_recorder.open_session(session_id~, timestamp~) catch {
    @interfaces.HistoryError::FileOpenFailed(path~, reason~) =>
      fail("PRODUCTION BUG: FileOpenFailed: path=\{path}, reason=\{reason}")
    @interfaces.HistoryError::DirectoryCreationFailed(path) =>
      fail("PRODUCTION BUG: DirectoryCreationFailed: \{path}")
    @interfaces.HistoryError::IoError(msg) =>
      fail("PRODUCTION BUG: IoError: \{msg}")
    @interfaces.HistoryError::PermissionDenied(path) =>
      fail("PRODUCTION BUG: PermissionDenied: \{path}")
    e => fail("PRODUCTION BUG: Unexpected error: \{e}")
  }

  assert_true(is_new, msg="Should be new session")

  // record SessionMeta
  let meta_record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({
      "channel": Json::string("web_chat"),
      "chat_id": Json::string(handler.chat_id),
      "test": Json::string("production_flow"),
    }),
  }
  handler.history_recorder.record(record=meta_record) catch {
    @interfaces.HistoryError::NotInitialized =>
      fail("PRODUCTION BUG: NotInitialized when recording")
    @interfaces.HistoryError::WriteFailed(expected~, actual~) =>
      fail("PRODUCTION BUG: WriteFailed: expected=\{expected}, actual=\{actual}")
    e => fail("PRODUCTION BUG: Record error: \{e}")
  }

  // close
  handler.history_recorder.close() catch { _ => () }

  // verify file exists
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }

  assert_eq(
    records.length(),
    1,
    msg="Should have 1 SessionMeta record, got \{records.length()}",
  )
}

// ============================================================
// 重要: async 関数内での trait object の動作テスト
// ============================================================

///|
/// async 関数内で trait object のメソッドを呼ぶヘルパー
async fn call_recorder_in_async(
  recorder : &@interfaces.HistoryRecorder,
  session_id : String,
  timestamp : Int64,
) -> Bool raise @interfaces.HistoryError {
  recorder.open_session(session_id~, timestamp~)
}

///|
async fn record_in_async(
  recorder : &@interfaces.HistoryRecorder,
  record : @interfaces.HistoryRecord,
) -> Unit raise @interfaces.HistoryError {
  recorder.record(record~)
}

async test "ASYNC: trait object mutable state in async function" {
  // async 関数内で trait object のメソッドを呼んだときに mutable state が保持されるか
  let data_dir = @config.data_dir()
  let unique_id = @native.c_time()
  let session_id = "web_chat:async-trait-test-\{unique_id}"
  let timestamp = unique_id * 1000L

  let recorder : &@interfaces.HistoryRecorder = @native.NativeHistoryRecorder::new(
    base_dir=data_dir,
  )

  // async 関数内で open_session を呼ぶ
  let is_new = call_recorder_in_async(recorder, session_id, timestamp) catch {
    e => fail("ASYNC: open_session failed: \{e}")
  }
  assert_true(is_new, msg="Should be new session")

  // async 関数内で record を呼ぶ
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "test": Json::string("async_trait") }),
  }
  record_in_async(recorder, record) catch {
    @interfaces.HistoryError::NotInitialized =>
      fail("ASYNC BUG: NotInitialized after async open_session!")
    e => fail("ASYNC: record failed: \{e}")
  }

  // close
  recorder.close() catch { _ => () }

  // 検証
  let reader = @native.NativeHistoryReader::new(base_dir=data_dir)
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 1, msg="Should have 1 record from async")
}

test "SYNC CONTEXT: calling async function from sync closure" {
  // プロダクションの run_forever 内のクロージャと同じパターン
  // 同期クロージャ内から async 関数を呼ぶ
  let data_dir = @config.data_dir()
  let unique_id = @native.c_time()
  let session_id = "web_chat:sync-closure-test-\{unique_id}"
  let timestamp = unique_id * 1000L

  // 同期クロージャを作成し、その中で async っぽい処理を呼ぶ
  let recorder : &@interfaces.HistoryRecorder = @native.NativeHistoryRecorder::new(
    base_dir=data_dir,
  )

  // 同期関数として直接呼ぶ（run_forever 内と同じ）
  let is_new = recorder.open_session(session_id~, timestamp~) catch {
    e => fail("SYNC CLOSURE: open_session failed: \{e}")
  }
  assert_true(is_new, msg="Should be new session")

  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "test": Json::string("sync_closure") }),
  }
  recorder.record(record~) catch {
    @interfaces.HistoryError::NotInitialized =>
      fail("SYNC CLOSURE BUG: NotInitialized!")
    e => fail("SYNC CLOSURE: record failed: \{e}")
  }

  recorder.close() catch { _ => () }

  // 検証
  let reader = @native.NativeHistoryReader::new(base_dir=data_dir)
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 1, msg="Should have 1 record from sync closure")
}

test "E2E: verify actual file creation with exact production pattern" {
  // プロダクションと完全に同じパターン:
  // 1. ChatWsHandler::new() で handler 作成
  // 2. handler.history_recorder.open_session() 呼び出し
  // 3. handler.history_recorder.record() 呼び出し
  // 4. ファイルが実際にディスクに存在することを確認

  let unique_id = @native.c_time()

  // プロダクションと同じ: ChatWsHandler::new()
  let handler = ChatWsHandler::new()

  // プロダクションの session_id 計算と同じ
  let session_id = "web_chat:\{handler.chat_id}"
  let timestamp = @native.c_time() * 1000 // get_timestamp_ms() と同じ（L なし）

  // open_session
  let is_new_session = handler.history_recorder.open_session(
    session_id~,
    timestamp~,
  ) catch {
    e => fail("E2E: open_session failed: \{e}")
  }

  // 必ず新規セッションのはず（chat_id はユニーク）
  if not(is_new_session) {
    // もし既存セッションなら、それは問題
    fail("E2E: Expected new session but got existing. chat_id=\{handler.chat_id}")
  }

  // SessionMeta を記録
  let meta_record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({
      "channel": Json::string("web_chat"),
      "chat_id": Json::string(handler.chat_id),
    }),
  }
  handler.history_recorder.record(record=meta_record) catch {
    @interfaces.HistoryError::NotInitialized =>
      fail("E2E BUG: NotInitialized - mutable state was lost!")
    @interfaces.HistoryError::WriteFailed(expected~, actual~) =>
      fail("E2E BUG: WriteFailed - expected \{expected} bytes, wrote \{actual}")
    e => fail("E2E: record failed: \{e}")
  }

  // close
  handler.history_recorder.close() catch { _ => () }

  // 実際のファイルパスを計算して存在確認
  let data_dir = @config.data_dir()
  let epoch_secs = timestamp / 1000L
  let (year, month, day) = @native.native_epoch_to_date(epoch_secs) catch {
    _ => fail("E2E: native_epoch_to_date failed")
  }
  let dir_path = @history.history_dir_for_date(data_dir, year, month, day)
  let (channel, chat_id) = @history.split_session_id(session_id)
  let file_path = @history.history_file_path(
    data_dir, channel, chat_id, year, month, day, epoch_secs,
  )

  // ファイル存在確認（FFI直接使用）
  let file_exists = @native.c_file_exists_bytes(@native.string_to_utf8_cstring(file_path))
  if file_exists != 1 {
    fail("E2E CRITICAL: File does not exist at: \{file_path}")
  }

  // ファイル内容確認
  let content = @native.native_read_file_text(file_path) catch {
    _ => fail("E2E: Failed to read created file: \{file_path}")
  }
  if content.length() == 0 {
    fail("E2E CRITICAL: File exists but is EMPTY: \{file_path}")
  }
  if not(content.contains("session_meta")) {
    fail("E2E: File content does not contain 'session_meta': \{content}")
  }
}

test "PRODUCTION PATTERN: ChatWsHandler in sync closure like run_forever" {
  // プロダクションの正確なパターンをシミュレート
  // - ChatWsHandler::new() を呼ぶ
  // - 同期的なコールバック内で history_recorder のメソッドを呼ぶ

  let unique_id = @native.c_time()
  let session_id = "web_chat:production-pattern-test-\{unique_id}"
  let timestamp = unique_id * 1000L

  // プロダクションと同じ: ChatWsHandler::new()
  let handler = ChatWsHandler::new()

  // プロダクションの handle_connection と同じフローを同期的に実行
  // （WebSocket 部分は除く）
  let is_new_session = handler.history_recorder.open_session(
    session_id~,
    timestamp~,
  ) catch {
    e => fail("PRODUCTION PATTERN: open_session failed: \{e}")
  }

  if is_new_session {
    let meta_record : @interfaces.HistoryRecord = {
      timestamp,
      session_id,
      record_type: @interfaces.HistoryRecordType::SessionMeta,
      payload: Json::object({
        "channel": Json::string("web_chat"),
        "chat_id": Json::string(handler.chat_id),
      }),
    }
    handler.history_recorder.record(record=meta_record) catch {
      @interfaces.HistoryError::NotInitialized =>
        fail("PRODUCTION PATTERN BUG: NotInitialized when recording!")
      e => fail("PRODUCTION PATTERN: record failed: \{e}")
    }
  } else {
    fail("PRODUCTION PATTERN: is_new_session should be true")
  }

  handler.history_recorder.close() catch { _ => () }

  // 検証
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 1, msg="Should have 1 record from production pattern")
}

async test "ASYNC: ChatWsHandler passed by value to async function" {
  // ChatWsHandler が async 関数に値渡しされたときに recorder の state が保持されるか
  // これがプロダクションの handle_connection と同じパターン

  let handler = ChatWsHandler::new()
  let unique_id = @native.c_time()
  let session_id = "web_chat:async-handler-test-\{unique_id}"
  let timestamp = unique_id * 1000L

  // handler を async 関数に渡して操作（プロダクションの handle_connection と同じ）
  simulate_handle_connection_async(handler, session_id, timestamp) catch {
    e => fail("simulate_handle_connection_async failed: \{e}")
  }

  // 検証: ファイルが作成されたか
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 1, msg="Should have 1 record from async handler")
}

///|
/// handle_connection の履歴記録部分をシミュレート
async fn simulate_handle_connection_async(
  handler : ChatWsHandler, // 値渡し（プロダクションと同じ）
  session_id : String,
  timestamp : Int64,
) -> Unit raise @interfaces.HistoryError {
  // プロダクションと同じフロー
  let is_new_session = handler.history_recorder.open_session(
    session_id~,
    timestamp~,
  )

  if is_new_session {
    let meta_record : @interfaces.HistoryRecord = {
      timestamp,
      session_id,
      record_type: @interfaces.HistoryRecordType::SessionMeta,
      payload: Json::object({
        "channel": Json::string("web_chat"),
        "chat_id": Json::string(handler.chat_id),
      }),
    }
    handler.history_recorder.record(record=meta_record)
  }

  handler.history_recorder.close()
}

test "CRITICAL: trait object in struct preserves mutable state across calls" {
  // ChatWsHandler と同じ構造をシミュレート
  // struct に trait object を格納し、複数回メソッドを呼び出す
  let data_dir = @config.data_dir()
  let unique_id = @native.c_time()
  let session_id = "web_chat:trait-struct-test-\{unique_id}"
  let timestamp = unique_id * 1000L

  // Step 1: recorder を作成し、struct に格納
  let recorder : &@interfaces.HistoryRecorder = @native.NativeHistoryRecorder::new(
    base_dir=data_dir,
  )

  // Step 2: open_session を呼び出し - これで initialized=true, file handle設定
  let is_new = recorder.open_session(session_id~, timestamp~) catch {
    e => fail("CRITICAL: open_session failed: \{e}")
  }
  assert_true(is_new, msg="Should be new session")

  // Step 3: 別の変数経由でもう一度 record を呼ぶ（プロダクションでの self.history_recorder 相当）
  let recorder_ref = recorder // 同じ参照を別変数に
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "test": Json::string("trait_struct") }),
  }
  recorder_ref.record(record~) catch {
    @interfaces.HistoryError::NotInitialized =>
      fail("CRITICAL BUG: NotInitialized after open_session - mutable state lost!")
    e => fail("CRITICAL: record failed: \{e}")
  }

  // Step 4: close
  recorder.close() catch { _ => () }

  // Step 5: 検証
  let reader = @native.NativeHistoryReader::new(base_dir=data_dir)
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 1, msg="Should have 1 record")
}

test "CRITICAL: ChatWsHandler.history_recorder preserves state" {
  // ChatWsHandler を作成し、その history_recorder の状態が保持されるか確認
  let handler = ChatWsHandler::new()
  let unique_id = @native.c_time()
  let session_id = "web_chat:handler-state-test-\{unique_id}"
  let timestamp = unique_id * 1000L

  // open_session
  let is_new = handler.history_recorder.open_session(session_id~, timestamp~) catch {
    e => fail("CRITICAL: open_session on handler failed: \{e}")
  }

  // record - handler.history_recorder 経由で呼び出し
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "source": Json::string("handler_test") }),
  }
  handler.history_recorder.record(record~) catch {
    @interfaces.HistoryError::NotInitialized =>
      fail("CRITICAL BUG: handler.history_recorder lost mutable state!")
    e => fail("CRITICAL: record failed: \{e}")
  }

  // close
  handler.history_recorder.close() catch { _ => () }

  // 検証
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 1, msg="Should have 1 record from handler")
}

test "CRITICAL: simulate exact production async flow" {
  // プロダクションの handle_connection と同じフローをシミュレート
  // ただし WebSocket なしで

  // 1. ChatWsHandler::new()
  let handler = ChatWsHandler::new()
  let unique_id = @native.c_time()

  // 2. create_session() - プロダクションではここで session store に保存
  handler.create_session()

  // 3. session_id と timestamp を計算
  let session_id = "web_chat:\{handler.chat_id}-async-sim-\{unique_id}"
  let timestamp = @native.c_time() * 1000 // L なし（プロダクションと同じ）

  // 4. open_session
  let is_new_session = handler.history_recorder.open_session(
    session_id~,
    timestamp~,
  ) catch {
    e => fail("ASYNC SIM: open_session failed: \{e}")
  }

  // 5. if is_new_session, record SessionMeta
  if is_new_session {
    let meta_record : @interfaces.HistoryRecord = {
      timestamp,
      session_id,
      record_type: @interfaces.HistoryRecordType::SessionMeta,
      payload: Json::object({
        "channel": Json::string("web_chat"),
        "chat_id": Json::string(handler.chat_id),
      }),
    }
    handler.history_recorder.record(record=meta_record) catch {
      @interfaces.HistoryError::NotInitialized =>
        fail("ASYNC SIM BUG: NotInitialized when recording meta!")
      e => fail("ASYNC SIM: record meta failed: \{e}")
    }
  } else {
    fail("ASYNC SIM: is_new_session should be true for unique session_id")
  }

  // 6. close
  handler.history_recorder.close() catch { _ => () }

  // 7. 検証
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 1, msg="ASYNC SIM: Should have 1 record")
}

test "generate_ws_chat_id: should produce different UUIDs on each call" {
  // generate_ws_chat_id が毎回異なる UUID を生成するか確認
  let uuid1 = generate_ws_chat_id()
  let uuid2 = generate_ws_chat_id()
  let uuid3 = generate_ws_chat_id()

  // 全て異なるはず
  assert_true(uuid1 != uuid2, msg="UUID1 and UUID2 should be different")
  assert_true(uuid2 != uuid3, msg="UUID2 and UUID3 should be different")
  assert_true(uuid1 != uuid3, msg="UUID1 and UUID3 should be different")

  // UUID v4 フォーマットのチェック（基本的なパターン）
  assert_eq(uuid1.length(), 36, msg="UUID should be 36 characters (with dashes)")
  assert_true(uuid1.contains("-"), msg="UUID should contain dashes")
}

test "ChatWsHandler::new: should produce different chat_ids" {
  // ChatWsHandler::new() が毎回異なる chat_id を生成するか確認
  let handler1 = ChatWsHandler::new()
  let handler2 = ChatWsHandler::new()
  let handler3 = ChatWsHandler::new()

  assert_true(
    handler1.chat_id != handler2.chat_id,
    msg="Handler1 and Handler2 should have different chat_ids",
  )
  assert_true(
    handler2.chat_id != handler3.chat_id,
    msg="Handler2 and Handler3 should have different chat_ids",
  )
  assert_true(
    handler1.chat_id != handler3.chat_id,
    msg="Handler1 and Handler3 should have different chat_ids",
  )
}

test "resume existing session: append to existing file works" {
  // 既存ファイルがある場合に追記できるか確認
  let data_dir = @config.data_dir()
  let unique_id = @native.c_time()
  let session_id = "web_chat:resume-test-\{unique_id}"
  let timestamp = unique_id * 1000L

  // 最初のセッション: ファイルを作成
  let recorder1 = @native.NativeHistoryRecorder::new(base_dir=data_dir)
  let is_new1 = recorder1.open_session(session_id~, timestamp~) catch {
    e => fail("First open_session failed: \{e}")
  }
  assert_true(is_new1, msg="First session should be new")

  // 最初のレコードを書き込み
  let record1 : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "seq": Json::number(1.0) }),
  }
  recorder1.record(record=record1) catch { e => fail("First record failed: \{e}") }
  recorder1.close() catch { _ => () }

  // 2番目のセッション: 同じ session_id で再オープン（追記）
  let recorder2 = @native.NativeHistoryRecorder::new(base_dir=data_dir)
  let is_new2 = recorder2.open_session(session_id~, timestamp~) catch {
    e => fail("Second open_session failed: \{e}")
  }
  assert_true(not(is_new2), msg="Second session should NOT be new (resuming)")

  // 2番目のレコードを書き込み
  let record2 : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({ "seq": Json::number(2.0), "content": Json::string("hello") }),
  }
  recorder2.record(record=record2) catch { e => fail("Second record failed: \{e}") }
  recorder2.close() catch { _ => () }

  // 検証: 両方のレコードが読める
  let reader = @native.NativeHistoryReader::new(base_dir=data_dir)
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 2, msg="Should have 2 records (1 from each session)")
}

test "handle_connection exact flow: using handler's own chat_id and recorder" {
  // handle_connection の完全なフローを再現
  // このテストは、プロダクションと完全に同じシーケンスを使う

  // 1. ChatWsHandler::new() で handler を作成
  let handler = ChatWsHandler::new()

  // 2. create_session (handle_connection line 216)
  handler.create_session()

  // 3. session_id と timestamp を取得 (handle_connection lines 220-221)
  let session_id = "web_chat:\{handler.chat_id}"
  let timestamp = @native.c_time() * 1000

  // 4. open_session (handle_connection lines 222-231)
  let is_new_session = handler.history_recorder.open_session(
    session_id~,
    timestamp~,
  ) catch {
    e => fail("handle_connection exact: open_session failed: \{e}")
  }

  // 5. if is_new_session, record SessionMeta (handle_connection lines 232-246)
  if is_new_session {
    let meta_record : @interfaces.HistoryRecord = {
      timestamp,
      session_id,
      record_type: @interfaces.HistoryRecordType::SessionMeta,
      payload: Json::object({
        "channel": Json::string("web_chat"),
        "chat_id": Json::string(handler.chat_id),
      }),
    }
    handler.history_recorder.record(record=meta_record) catch {
      e => fail("handle_connection exact: record failed: \{e}")
    }
  }

  // 6. close (handle_connection lines 275-277)
  handler.history_recorder.close() catch { _ => () }

  // 7. 検証: ファイルが作成され、内容があるか
  let reader = @native.NativeHistoryReader::new(base_dir=@config.data_dir())
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }

  // ファイルにSessionMetaが記録されているはず
  // is_new_session が true の場合のみ記録されるので、
  // 既存ファイルがある場合（前回のテスト実行）は records が多くなる可能性あり
  assert_true(
    records.length() >= 1,
    msg="Should have at least 1 record, got \{records.length()}",
  )
}
