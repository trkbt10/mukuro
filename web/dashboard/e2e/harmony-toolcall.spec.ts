import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { spawn, ChildProcess } from 'child_process';
import { fileURLToPath } from 'url';

/**
 * Harmony Toolcall E2E Test
 *
 * Tests builtin tools through Harmony (Responses API -> Chat Completions) translation.
 * Verifies that datetime, shell, and filesystem tools work correctly when the LLM
 * uses Responses API format internally but the provider (Groq) uses Chat Completions.
 *
 * Prerequisites:
 * - mukuro binary built: ./scripts/build-native.sh
 * - Run with: GROQ_API_KEY=<key> npx playwright test e2e/harmony-toolcall.spec.ts
 */

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const MUKURO_BINARY = path.join(__dirname, '../../../_build/native/debug/build/mukuro.exe');
const GROQ_API_KEY = process.env.GROQ_API_KEY;
const TEST_PORT = 6962;

interface TestContext {
  tmpDir: string;
  process: ChildProcess | null;
  host: string;
  port: number;
}

let ctx: TestContext;

async function waitForServer(host: string, port: number, timeoutMs = 30000): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(`http://${host}:${port}/api/v1/onboard/status`);
      if (res.ok) return true;
    } catch {
      // Server not ready yet
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  return false;
}

async function startMukuro(): Promise<void> {
  if (!fs.existsSync(MUKURO_BINARY)) {
    throw new Error(`mukuro binary not found at ${MUKURO_BINARY}. Run ./scripts/build-native.sh first.`);
  }

  // Create config.json with groq provider
  const configPath = path.join(ctx.tmpDir, 'config.json');
  fs.writeFileSync(
    configPath,
    JSON.stringify({
      agent: { max_iterations: 12, model_options: { model_name: 'openai/gpt-oss-20b' } },
      providers: [
        {
          name: 'groq',
          api_key: GROQ_API_KEY,
          base_url: 'https://api.groq.com/openai',
          default_model: 'openai/gpt-oss-20b',
          use_responses_api: true, // Harmony translation enabled
        },
      ],
      fallback: { enabled: false, providers: [], cooldown_ms: 30000 },
      thinking: { enabled: false, level: 'off' },
    })
  );

  ctx.process = spawn(
    MUKURO_BINARY,
    ['--data-dir', ctx.tmpDir, 'gateway', '--config', configPath, '--port', String(ctx.port), '--control-api'],
    {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env },
    }
  );

  let stdout = '';
  let stderr = '';
  ctx.process.stdout?.on('data', (data) => {
    stdout += data.toString();
  });
  ctx.process.stderr?.on('data', (data) => {
    stderr += data.toString();
  });

  const ready = await waitForServer(ctx.host, ctx.port);
  if (!ready) {
    console.error('stdout:', stdout);
    console.error('stderr:', stderr);
    throw new Error('mukuro server failed to start');
  }
}

function stopMukuro(): void {
  if (ctx.process) {
    ctx.process.kill('SIGTERM');
    ctx.process = null;
  }
}

/**
 * Helper to send a message and wait for assistant response via WebSocket
 */
async function sendAndWaitForResponse(
  page: Awaited<ReturnType<typeof test.info>['page']>,
  host: string,
  port: number,
  message: string,
  timeoutMs = 60000
): Promise<{ response: string | null; error: string | null; toolCalls: string[] }> {
  return page.evaluate(
    async ({ host, port, message, timeoutMs }) => {
      return new Promise<{ response: string | null; error: string | null; toolCalls: string[] }>((resolve) => {
        const ws = new WebSocket(`ws://${host}:${port}/ws/chat`);
        const toolCalls: string[] = [];
        let response: string | null = null;

        const timeout = setTimeout(() => {
          ws.close();
          resolve({ response, error: 'Timeout', toolCalls });
        }, timeoutMs);

        ws.onmessage = (event) => {
          const msg = JSON.parse(event.data);

          if (msg.type === 'session') {
            ws.send(JSON.stringify({ type: 'send', content: message }));
          }

          // Capture tool calls
          if (msg.type === 'tool_call') {
            toolCalls.push(msg.tool_name || msg.name || 'unknown');
          }

          if (msg.type === 'message' && msg.role === 'assistant') {
            response = msg.content;
            clearTimeout(timeout);
            setTimeout(() => {
              ws.close();
              resolve({ response, error: null, toolCalls });
            }, 500);
          }

          if (msg.type === 'error') {
            clearTimeout(timeout);
            ws.close();
            resolve({ response, error: msg.error, toolCalls });
          }
        };

        ws.onerror = () => {
          clearTimeout(timeout);
          resolve({ response, error: 'WebSocket error', toolCalls });
        };
      });
    },
    { host, port, message, timeoutMs }
  );
}

test.describe.serial('Harmony Toolcall E2E', () => {
  test.skip(!GROQ_API_KEY, 'Requires GROQ_API_KEY environment variable');

  test.beforeAll(async () => {
    ctx = {
      tmpDir: fs.mkdtempSync(path.join(os.tmpdir(), 'mukuro-harmony-test-')),
      process: null,
      host: 'localhost',
      port: TEST_PORT,
    };
    console.log(`Test data directory: ${ctx.tmpDir}`);
    await startMukuro();

    // Complete onboarding to enable agent
    await fetch(`http://${ctx.host}:${ctx.port}/api/v1/onboard/complete`, {
      method: 'POST',
    });
  });

  test.afterAll(() => {
    stopMukuro();
    if (ctx?.tmpDir && fs.existsSync(ctx.tmpDir)) {
      fs.rmSync(ctx.tmpDir, { recursive: true, force: true });
    }
  });

  test('datetime tool: get current time', async ({ page }) => {
    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'What is the current time? Use the datetime tool to check.'
    );

    console.log('Datetime result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Response should contain time-related information
    expect(
      result.response?.toLowerCase().includes('time') ||
        result.response?.toLowerCase().includes('date') ||
        result.response?.match(/\d{4}-\d{2}-\d{2}/) || // ISO date
        result.response?.match(/\d{1,2}:\d{2}/) // Time format
    ).toBeTruthy();
  });

  test('shell tool: execute simple command', async ({ page }) => {
    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Run "echo hello-harmony-test" using the shell tool and tell me the output.'
    );

    console.log('Shell result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Response should contain the echo output
    expect(result.response?.toLowerCase().includes('hello-harmony-test') || result.response?.includes('hello')).toBeTruthy();
  });

  test('filesystem tool: read file', async ({ page }) => {
    // Create a test file first
    const testFilePath = path.join(ctx.tmpDir, 'test-file.txt');
    const testContent = 'Hello from Harmony filesystem test!';
    fs.writeFileSync(testFilePath, testContent);

    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      `Use the filesystem tool to read the file at ${testFilePath} and tell me its contents.`
    );

    console.log('Filesystem read result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Response should reference the file content
    expect(
      result.response?.includes('Hello') ||
        result.response?.includes('Harmony') ||
        result.response?.includes('filesystem')
    ).toBeTruthy();
  });

  test('filesystem tool: write and read back', async ({ page }) => {
    const testFilePath = path.join(ctx.tmpDir, 'harmony-write-test.txt');
    const testContent = 'Content written by Harmony test at ' + new Date().toISOString();

    // Ask to write a file
    const writeResult = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      `Use the filesystem tool to write this content to ${testFilePath}: "${testContent}". Then confirm the file was created.`
    );

    console.log('Filesystem write result:', writeResult);

    expect(writeResult.error).toBeNull();

    // Verify file was actually created
    await new Promise((r) => setTimeout(r, 1000));
    const fileExists = fs.existsSync(testFilePath);
    expect(fileExists).toBe(true);

    if (fileExists) {
      const actualContent = fs.readFileSync(testFilePath, 'utf-8');
      console.log('Written file content:', actualContent);
      expect(actualContent).toContain('Harmony');
    }
  });

  test('multiple tools in sequence: datetime then shell', async ({ page }) => {
    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'First, use the datetime tool to get the current timestamp. Then use the shell tool to run "pwd". Tell me both results.',
      90000 // Longer timeout for multi-tool sequence
    );

    console.log('Multi-tool result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Should mention both time and directory
    expect(result.response).toBeTruthy();
  });

  test('tool with large output: shell ls', async ({ page }) => {
    // Create multiple files to have some output
    for (let i = 0; i < 10; i++) {
      fs.writeFileSync(path.join(ctx.tmpDir, `testfile-${i}.txt`), `content ${i}`);
    }

    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      `Use the shell tool to run "ls -la ${ctx.tmpDir}" and summarize what files you see.`
    );

    console.log('Large output result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Should mention files
    expect(
      result.response?.toLowerCase().includes('file') || result.response?.toLowerCase().includes('testfile')
    ).toBeTruthy();
  });

  // =========================================================================
  // Error Cases
  // =========================================================================

  test('filesystem tool: read non-existent file (error handling)', async ({ page }) => {
    const nonExistentPath = path.join(ctx.tmpDir, 'this-file-does-not-exist-12345.txt');

    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      `Use the filesystem tool to read the file at ${nonExistentPath}. If it fails, tell me about the error.`
    );

    console.log('Non-existent file result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Should mention error, not found, or doesn't exist
    expect(
      result.response?.toLowerCase().includes('error') ||
        result.response?.toLowerCase().includes('not found') ||
        result.response?.toLowerCase().includes('not exist') ||
        result.response?.toLowerCase().includes('does not exist') ||
        result.response?.toLowerCase().includes('failed')
    ).toBeTruthy();
  });

  test('shell tool: command with non-zero exit (error handling)', async ({ page }) => {
    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Use the shell tool to run "ls /nonexistent-directory-xyz". Tell me what happened.'
    );

    console.log('Shell error result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Should mention error or no such directory
    expect(
      result.response?.toLowerCase().includes('error') ||
        result.response?.toLowerCase().includes('no such') ||
        result.response?.toLowerCase().includes('not found') ||
        result.response?.toLowerCase().includes('does not exist')
    ).toBeTruthy();
  });

  // =========================================================================
  // Web Tool
  // =========================================================================

  test('web tool: fetch public API', async ({ page }) => {
    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Use the web tool to fetch https://httpbin.org/get and tell me what you received.',
      90000
    );

    console.log('Web fetch result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Should mention something about the response (headers, origin, etc.)
    expect(
      result.response?.toLowerCase().includes('origin') ||
        result.response?.toLowerCase().includes('headers') ||
        result.response?.toLowerCase().includes('httpbin') ||
        result.response?.toLowerCase().includes('response') ||
        result.response?.toLowerCase().includes('url')
    ).toBeTruthy();
  });

  // =========================================================================
  // Memory Tool
  // =========================================================================

  test('memory tool: store and retrieve value', async ({ page }) => {
    // First, store a value
    const storeResult = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Use the memory tool to store my favorite color as "blue" with key "user_favorite_color". Confirm it was stored.'
    );

    console.log('Memory store result:', storeResult);

    expect(storeResult.error).toBeNull();
    expect(storeResult.response).toBeTruthy();

    // Then retrieve it in a new conversation turn
    const retrieveResult = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Use the memory tool to get the value for key "user_favorite_color". What is my favorite color?'
    );

    console.log('Memory retrieve result:', retrieveResult);

    expect(retrieveResult.error).toBeNull();
    expect(retrieveResult.response).toBeTruthy();
    // Should mention blue
    expect(retrieveResult.response?.toLowerCase().includes('blue')).toBeTruthy();
  });

  test('memory tool: list and search', async ({ page }) => {
    // Store multiple values
    await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Use the memory tool to store "Tokyo" with key "user_city" and "Japanese" with key "user_language".'
    );

    // List all keys
    const listResult = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Use the memory tool to list all stored keys. What keys are available?'
    );

    console.log('Memory list result:', listResult);

    expect(listResult.error).toBeNull();
    expect(listResult.response).toBeTruthy();

    // Search for user-related keys
    const searchResult = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Use the memory tool to search for keys containing "user". What did you find?'
    );

    console.log('Memory search result:', searchResult);

    expect(searchResult.error).toBeNull();
    expect(searchResult.response).toBeTruthy();
  });

  // =========================================================================
  // Unicode / Japanese Content
  // =========================================================================

  test('filesystem tool: write and read Japanese content', async ({ page }) => {
    const testFilePath = path.join(ctx.tmpDir, 'japanese-test.txt');
    const japaneseContent = 'こんにちは、世界！これはHarmonyテストです。日本語の文字列。';

    // Write Japanese content
    const writeResult = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      `Use the filesystem tool to write this Japanese text to ${testFilePath}: "${japaneseContent}"`
    );

    console.log('Japanese write result:', writeResult);

    expect(writeResult.error).toBeNull();

    // Verify file content
    await new Promise((r) => setTimeout(r, 500));
    if (fs.existsSync(testFilePath)) {
      const actualContent = fs.readFileSync(testFilePath, 'utf-8');
      console.log('Written Japanese content:', actualContent);
      // Should contain some Japanese characters
      expect(actualContent.includes('こんにちは') || actualContent.includes('日本語')).toBeTruthy();
    }

    // Read it back
    const readResult = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      `Use the filesystem tool to read ${testFilePath}. What Japanese text is in the file?`
    );

    console.log('Japanese read result:', readResult);

    expect(readResult.error).toBeNull();
    expect(readResult.response).toBeTruthy();
  });

  test('shell tool: echo Japanese text', async ({ page }) => {
    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Use the shell tool to run: echo "テスト: 日本語出力"'
    );

    console.log('Japanese shell result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Should contain Japanese characters in response
    expect(
      result.response?.includes('テスト') ||
        result.response?.includes('日本語') ||
        result.response?.includes('japanese') ||
        result.response?.toLowerCase().includes('output')
    ).toBeTruthy();
  });

  test('memory tool: store Japanese value', async ({ page }) => {
    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      'Use the memory tool to store "東京都渋谷区" with key "user_address_japanese". Then retrieve it and tell me the value.'
    );

    console.log('Japanese memory result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Should contain Japanese address
    expect(
      result.response?.includes('東京') ||
        result.response?.includes('渋谷') ||
        result.response?.toLowerCase().includes('tokyo') ||
        result.response?.toLowerCase().includes('shibuya')
    ).toBeTruthy();
  });

  // =========================================================================
  // Parallel Tool Calls (if LLM supports)
  // =========================================================================

  test('parallel tools: datetime and filesystem in one request', async ({ page }) => {
    const testFilePath = path.join(ctx.tmpDir, 'parallel-test.txt');
    fs.writeFileSync(testFilePath, 'Parallel test content');

    const result = await sendAndWaitForResponse(
      page,
      ctx.host,
      ctx.port,
      `I need two things at once: 1) Use datetime tool to get current time, 2) Use filesystem tool to read ${testFilePath}. Report both results.`,
      90000
    );

    console.log('Parallel tools result:', result);

    expect(result.error).toBeNull();
    expect(result.response).toBeTruthy();
    // Should mention both time and file content
    expect(result.response).toBeTruthy();
  });
});
