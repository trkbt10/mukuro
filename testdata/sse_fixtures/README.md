# SSE Fixtures

LLM API の SSE (Server-Sent Events) ストリーミングレスポンスを実際にキャプチャしたテストフィクスチャ。
SSE パーサーの実装・検証に使用する。

## ディレクトリ構成

```
testdata/sse_fixtures/
├── groq/
│   ├── chat_completions/   # OpenAI Chat Completions 互換 (/v1/chat/completions)
│   ├── responses/          # OpenAI Responses API 互換 (/v1/responses)
│   ├── models/             # GET /v1/models
│   └── errors/             # エラーレスポンス
├── anthropic/
│   ├── messages/           # Anthropic Messages API (/v1/messages)
│   ├── models/             # GET /v1/models
│   └── errors/             # エラーレスポンス
├── openai/
│   ├── responses/          # OpenAI Responses API (/v1/responses)
│   ├── models/             # GET /v1/models
│   └── errors/             # エラーレスポンス
└── README.md
```

### messages / chat_completions / responses 内のファイル命名規則

| ファイル | 内容 |
|---|---|
| `text_nonstream.json` | テキスト応答（非ストリーム） |
| `text_stream_raw.txt` | テキスト応答 SSE 生データ |
| `text_stream.jsonl` | テキスト応答 SSE を JSONL に変換 |
| `toolcall_nonstream.json` | ツールコール応答（非ストリーム） |
| `toolcall_stream_raw.txt` | ツールコール SSE 生データ |
| `toolcall_stream.jsonl` | ツールコール SSE を JSONL に変換 |
| `toolresult_stream_raw.txt` | ツール結果→最終応答 SSE 生データ |
| `toolresult_stream.jsonl` | ツール結果→最終応答 SSE を JSONL に変換 |

### models/ 内のファイル

| ファイル | 内容 |
|---|---|
| `list.json` | `GET /v1/models` — モデル一覧 |
| `get.json` | `GET /v1/models/{id}` — 単一モデル詳細 |

### errors/ 内のファイル

| ファイル | 内容 |
|---|---|
| `auth_error.json` | 401 認証エラー |
| `invalid_model.json` | 404 存在しないモデル |

### anthropic/messages/ 追加ファイル

| ファイル | 内容 |
|---|---|
| `count_tokens.json` | `POST /v1/messages/count_tokens` — トークンカウント |

### openai/responses/ 追加ファイル

| ファイル | 内容 |
|---|---|
| `websearch_nonstream.json` | Web検索応答（非ストリーム） |
| `websearch_stream_raw.txt` | Web検索 SSE 生データ |
| `websearch_stream.jsonl` | Web検索 SSE を JSONL に変換 |

## キャプチャ時の条件

- **日時**: 2026-02-28
- **Groq モデル**: `openai/gpt-oss-20b`
- **Anthropic モデル**: `claude-sonnet-4-6`
- **OpenAI モデル**: `gpt-4o-mini`
- **プロンプト (テキスト)**: system="You are a helpful assistant. Reply briefly." / user="What is 2+2? Reply in one word."
- **プロンプト (ツールコール)**: user="What is the weather in Tokyo?" + `get_weather` ツール定義
- **ツール結果**: `{"temperature":22,"condition":"Partly cloudy","humidity":65}`

## 再キャプチャ手順

API キーを環境変数にセットしてから curl で取得する。

### Groq Chat Completions (stream)

```sh
curl -sS --no-buffer \
  -X POST "https://api.groq.com/openai/v1/chat/completions" \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-oss-20b",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant. Reply briefly."},
      {"role": "user", "content": "What is 2+2? Reply in one word."}
    ],
    "stream": true
  }' > groq/chat_completions/text_stream_raw.txt
```

### Groq Responses API (stream)

```sh
curl -sS --no-buffer \
  -X POST "https://api.groq.com/openai/v1/responses" \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-oss-20b",
    "input": [
      {"role": "system", "content": [{"type": "input_text", "text": "You are a helpful assistant. Reply briefly."}]},
      {"role": "user", "content": [{"type": "input_text", "text": "What is 2+2? Reply in one word."}]}
    ],
    "stream": true
  }' > groq/responses/text_stream_raw.txt
```

### Anthropic Messages API (stream)

```sh
curl -sS --no-buffer \
  -X POST "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 256,
    "system": "You are a helpful assistant. Reply briefly.",
    "messages": [{"role": "user", "content": "What is 2+2? Reply in one word."}],
    "stream": true
  }' > anthropic/messages/text_stream_raw.txt
```

### OpenAI Responses API (stream)

```sh
curl -sS --no-buffer \
  -X POST "https://api.openai.com/v1/responses" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "input": [
      {"role": "system", "content": [{"type": "input_text", "text": "You are a helpful assistant. Reply briefly."}]},
      {"role": "user", "content": [{"type": "input_text", "text": "What is 2+2? Reply in one word."}]}
    ],
    "stream": true
  }' > openai/responses/text_stream_raw.txt
```

### OpenAI Responses API — Web検索 (stream)

```sh
curl -sS --no-buffer \
  -X POST "https://api.openai.com/v1/responses" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "input": [
      {"role": "user", "content": [{"type": "input_text", "text": "What is the current weather in Tokyo?"}]}
    ],
    "tools": [{"type": "web_search_preview"}],
    "stream": true
  }' > openai/responses/websearch_stream_raw.txt
```

### Models

```sh
# Groq
curl -sS "https://api.groq.com/openai/v1/models" \
  -H "Authorization: Bearer $GROQ_API_KEY" > groq/models/list.json

curl -sS "https://api.groq.com/openai/v1/models/openai/gpt-oss-20b" \
  -H "Authorization: Bearer $GROQ_API_KEY" > groq/models/get.json

# Anthropic
curl -sS "https://api.anthropic.com/v1/models?limit=100" \
  -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" \
  > anthropic/models/list.json

curl -sS "https://api.anthropic.com/v1/models/claude-sonnet-4-6" \
  -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" \
  > anthropic/models/get.json

# OpenAI
curl -sS "https://api.openai.com/v1/models" \
  -H "Authorization: Bearer $OPENAI_API_KEY" > openai/models/list.json

curl -sS "https://api.openai.com/v1/models/gpt-4o-mini" \
  -H "Authorization: Bearer $OPENAI_API_KEY" > openai/models/get.json
```

### Anthropic count_tokens

```sh
curl -sS -X POST "https://api.anthropic.com/v1/messages/count_tokens" \
  -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-sonnet-4-6","system":"...","messages":[...]}' \
  > anthropic/messages/count_tokens.json
```

### raw → JSONL 変換

sh のみで実行可能。外部依存なし。

```sh
# Chat Completions 形式 (event ヘッダーなし — data: 行のみ)
grep '^data: ' RAW_FILE.txt | sed 's/^data: //' > OUTPUT.jsonl

# Responses / Anthropic 形式 (event: + data: ペア → {"event":"...","data":{...}} の JSONL)
awk '
  /^event: / { ev = substr($0, 8) }
  /^data: /  {
    d = substr($0, 7)
    printf "{\"event\":\"%s\",\"data\":%s}\n", ev, d
    ev = ""
  }
' RAW_FILE.txt > OUTPUT.jsonl
```

## プロトコル差分メモ

### SSE 形式

| | Groq Chat Completions | Groq/OpenAI Responses API | Anthropic Messages |
|---|---|---|---|
| event ヘッダー | なし | あり | あり |
| 終端 | `data: [DONE]` | `response.completed` | `message_stop` |
| テキスト delta | `delta.content` | `response.output_text.delta` | `text_delta` |

### ツールコール

| | Groq Chat Completions | Groq/OpenAI Responses API | Anthropic Messages |
|---|---|---|---|
| 呼び出し | `delta.tool_calls[].function` | `function_call_arguments.delta` | `content_block_start` (tool_use) + `input_json_delta` |
| 完了判定 | `finish_reason: "tool_calls"` | `response.completed` | `stop_reason: "tool_use"` |
| ID 形式 | `fc_xxx` | `fc_xxx` (= call_id) | `toolu_xxx` |

### ツール結果の入力形式

| | Groq Chat Completions | Groq/OpenAI Responses API | Anthropic Messages |
|---|---|---|---|
| role/type | `role: "tool"` | `type: "function_call_output"` | `role: "user"` 内の `type: "tool_result"` |
| ID キー | `tool_call_id` | `call_id` | `tool_use_id` |

### OpenAI 固有: Web検索イベント

OpenAI Responses API の `web_search_preview` ツール使用時に発生する固有イベント:

| イベント | 内容 |
|---|---|
| `response.web_search_call.in_progress` | Web検索開始 |
| `response.web_search_call.searching` | 検索実行中 |
| `response.web_search_call.completed` | 検索完了（`action.queries` に検索クエリ一覧） |

出力構造: `web_search_call` アイテム（検索結果） → `message` アイテム（テキスト応答 + annotations）の順。
