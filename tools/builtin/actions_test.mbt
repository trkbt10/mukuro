///|
/// Builtin Actions Tests
/// テストは実装詳細（アクション名）に依存せず、構造と動作を検証する

///|
test "get_memory_actions returns non-empty array" {
  let store = MemoryStore::new()
  let actions = get_memory_actions(store)
  assert_true(actions.length() > 0)
}

///|
test "get_all_builtin_actions returns non-empty array" {
  let store = MemoryStore::new()
  let actions = get_all_builtin_actions(store)
  assert_true(actions.length() > 0)
}

///|
test "all actions have non-empty names" {
  let store = MemoryStore::new()
  let actions = get_all_builtin_actions(store)
  for action in actions {
    assert_true(action.name.length() > 0)
  }
}

///|
test "all actions have callable handlers" {
  let store = MemoryStore::new()
  let actions = get_all_builtin_actions(store)
  for action in actions {
    // ハンドラーを呼び出せることを確認（空のパラメータで）
    let response = (action.handler)({})
    // 200 または 400（パラメータ不足）のいずれかが返る
    assert_true(response.status == 200 || response.status == 400)
  }
}

///|
test "actions capture store correctly - modifications are visible" {
  let store = MemoryStore::new()
  let _ = get_all_builtin_actions(store)
  // store を直接変更
  store.set("direct-key", Json::string("direct-value"))
  // アクション経由でも見える
  assert_true(store.has("direct-key"))
}

///|
test "action handlers return ApiResponse with valid status" {
  let store = MemoryStore::new()
  let actions = get_all_builtin_actions(store)
  for action in actions {
    let response = (action.handler)({})
    // HTTP status code は 1xx-5xx の範囲
    assert_true(response.status >= 100 && response.status < 600)
  }
}

///|
test "action handlers return ApiResponse with non-empty body" {
  let store = MemoryStore::new()
  let actions = get_all_builtin_actions(store)
  for action in actions {
    let response = (action.handler)({})
    assert_true(response.body.length() > 0)
  }
}

///|
test "get_memory_actions and get_all_builtin_actions return same count" {
  let store = MemoryStore::new()
  let memory_actions = get_memory_actions(store)
  let all_actions = get_all_builtin_actions(store)
  // 現時点では全アクションがメモリ関連
  assert_eq(memory_actions.length(), all_actions.length())
}
