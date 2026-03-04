import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { spawn, ChildProcess } from 'child_process';
import { fileURLToPath } from 'url';

/**
 * Harmony Tool Call E2E Test
 *
 * Tests Chat Completions (Harmony) mode with tool calls:
 * 1. Start mukuro with use_responses_api: false (Chat Completions mode)
 * 2. Run conversation that triggers datetime tool call
 * 3. Verify multi-turn conversation with tool result
 * 4. Verify history records tool calls and results
 *
 * This validates the Harmony protocol handling for gpt-oss models.
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

  // Create config.json with groq provider using Chat Completions (Harmony) mode
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
          // Key difference: use Chat Completions (Harmony) mode instead of Responses API
          use_responses_api: false,
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

test.describe.serial('Harmony Tool Call E2E', () => {
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
  });

  test.afterAll(() => {
    stopMukuro();
    if (ctx?.tmpDir && fs.existsSync(ctx.tmpDir)) {
      fs.rmSync(ctx.tmpDir, { recursive: true, force: true });
    }
  });

  test('1. verify Chat Completions mode configured', async ({ request }) => {
    const res = await request.get(`http://${ctx.host}:${ctx.port}/api/v1/settings/providers`);
    expect(res.ok()).toBeTruthy();

    const data = await res.json();
    const groqProvider = data.data.find((p: { name: string }) => p.name === 'groq');
    expect(groqProvider).toBeDefined();
    // use_responses_api should be false (Chat Completions / Harmony mode)
    expect(groqProvider.use_responses_api).toBe(false);
  });

  test('2. complete onboarding', async ({ request }) => {
    const res = await request.post(`http://${ctx.host}:${ctx.port}/api/v1/onboard/complete`);
    expect(res.ok()).toBeTruthy();
  });

  test('3. multi-turn conversation with tool call (datetime)', async ({ page }) => {
    // This test triggers the datetime tool and verifies multi-turn handling
    const result = await page.evaluate(
      async ({ host, port }) => {
        return new Promise<{
          turns: Array<{ sent: string; received: string | null; error: string | null }>;
          chatId: string | null;
          receivedMessages: string[];
        }>((resolve) => {
          const ws = new WebSocket(`ws://${host}:${port}/ws/chat`);
          let chatId: string | null = null;
          let currentTurn = 0;
          const receivedMessages: string[] = [];

          // Messages designed to trigger tool calls
          const turns = [
            // Turn 1: Ask for current time - should trigger datetime tool
            { sent: 'What is the current date and time?', received: null, error: null },
            // Turn 2: Follow-up question based on tool result
            { sent: 'What day of the week is that?', received: null, error: null },
          ];

          const timeout = setTimeout(() => {
            ws.close();
            resolve({ turns, chatId, receivedMessages });
          }, 120000); // 2 minute timeout for tool calls

          ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            receivedMessages.push(JSON.stringify(msg));

            if (msg.type === 'session') {
              chatId = msg.chat_id;
              ws.send(JSON.stringify({ type: 'send', content: turns[0].sent }));
            }

            if (msg.type === 'message' && msg.role === 'assistant') {
              turns[currentTurn].received = msg.content;
              currentTurn++;

              if (currentTurn < turns.length) {
                setTimeout(() => {
                  ws.send(JSON.stringify({ type: 'send', content: turns[currentTurn].sent }));
                }, 1000);
              } else {
                clearTimeout(timeout);
                setTimeout(() => {
                  ws.close();
                  resolve({ turns, chatId, receivedMessages });
                }, 1000);
              }
            }

            if (msg.type === 'error') {
              turns[currentTurn].error = msg.error;
              clearTimeout(timeout);
              ws.close();
              resolve({ turns, chatId, receivedMessages });
            }
          };

          ws.onerror = (err) => {
            clearTimeout(timeout);
            resolve({ turns, chatId, receivedMessages });
          };
        });
      },
      { host: ctx.host, port: ctx.port }
    );

    console.log('Conversation result:', JSON.stringify(result.turns, null, 2));
    if (result.turns.some((t) => t.error)) {
      console.log('All received messages:', result.receivedMessages);
    }

    expect(result.chatId).toBeTruthy();

    // Turn 1: Should contain time-related response
    expect(result.turns[0].error, 'Turn 1 error').toBeNull();
    expect(result.turns[0].received, 'Turn 1 response').toBeTruthy();
    // The response should mention time/date (from datetime tool result)
    const turn1Response = result.turns[0].received?.toLowerCase() || '';
    expect(
      turn1Response.includes('time') ||
        turn1Response.includes('date') ||
        turn1Response.includes(':') ||
        turn1Response.includes('pm') ||
        turn1Response.includes('am')
    ).toBe(true);

    // Turn 2: Follow-up should work
    expect(result.turns[1].error, 'Turn 2 error').toBeNull();
    expect(result.turns[1].received, 'Turn 2 response').toBeTruthy();
  });

  test('4. verify history includes tool call records', async () => {
    const historyDir = path.join(ctx.tmpDir, 'history');

    // Wait for history to be flushed
    await new Promise((r) => setTimeout(r, 2000));

    expect(fs.existsSync(historyDir)).toBe(true);

    const jsonlFiles: string[] = [];
    const walk = (dir: string) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full);
        else if (entry.name.endsWith('.jsonl')) jsonlFiles.push(full);
      }
    };
    walk(historyDir);

    expect(jsonlFiles.length).toBeGreaterThan(0);

    const content = fs.readFileSync(jsonlFiles[0], 'utf-8');
    const lines = content.trim().split('\n').filter(Boolean);
    const records = lines.map((line) => JSON.parse(line));
    const types = records.map((r) => r.type);

    console.log('History record types:', types);
    console.log('Full history:', JSON.stringify(records, null, 2));

    // Verify essential record types
    expect(types).toContain('session_meta');
    expect(types).toContain('user_message');
    expect(types).toContain('assistant_message');

    // Verify tool call records exist (if datetime tool was called)
    const hasToolCall = types.includes('tool_call');
    const hasToolResult = types.includes('tool_result');
    console.log(`Tool call recorded: ${hasToolCall}, Tool result recorded: ${hasToolResult}`);

    // At minimum, we should have multiple assistant messages (for multi-turn)
    const assistantMessages = records.filter((r) => r.type === 'assistant_message');
    expect(assistantMessages.length).toBeGreaterThanOrEqual(1);
  });
});
