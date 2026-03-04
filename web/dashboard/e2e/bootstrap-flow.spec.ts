import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { spawn, ChildProcess } from 'child_process';
import { fileURLToPath } from 'url';

/**
 * Bootstrap Flow E2E Test
 *
 * Tests the complete onboarding flow from scratch in isolated tmp directory:
 * 1. Start mukuro with empty data directory
 * 2. Configure provider via API
 * 3. Complete onboarding
 * 4. Run multi-turn conversation
 * 5. Verify history is recorded
 *
 * Prerequisites:
 * - mukuro binary built: ./scripts/build-native.sh
 * - Run with: GROQ_API_KEY=<key> npx playwright test e2e/bootstrap-flow.spec.ts
 *
 * Or extract key from config:
 *   GROQ_API_KEY=$(cat ~/Library/Application\ Support/mukuro/config.json | jq -r '.providers[0].api_key') \
 *   npx playwright test e2e/bootstrap-flow.spec.ts
 */

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const MUKURO_BINARY = path.join(__dirname, '../../../_build/native/debug/build/mukuro.exe');
const GROQ_API_KEY = process.env.GROQ_API_KEY;
const TEST_PORT = 6961;

interface TestContext {
  tmpDir: string;
  process: ChildProcess | null;
  host: string;
  port: number;
}

// Shared context across all tests in this file
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

  // Create config.json with groq provider in tmp directory
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
          use_responses_api: true,
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

test.describe.serial('Bootstrap Flow E2E', () => {
  test.skip(!GROQ_API_KEY, 'Requires GROQ_API_KEY environment variable');

  test.beforeAll(async () => {
    ctx = {
      tmpDir: fs.mkdtempSync(path.join(os.tmpdir(), 'mukuro-bootstrap-test-')),
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

  test('1. initial state: provider configured from config file', async ({ request }) => {
    const res = await request.get(`http://${ctx.host}:${ctx.port}/api/v1/onboard/status`);
    expect(res.ok()).toBeTruthy();

    const data = await res.json();
    // Fresh start with provider in config should be not_started or in_progress
    expect(['not_started', 'in_progress']).toContain(data.data.status);
    // Provider is configured via config.json
    expect(data.data.has_provider).toBe(true);
  });

  test('2. verify groq provider is available', async ({ request }) => {
    const res = await request.get(`http://${ctx.host}:${ctx.port}/api/v1/settings/providers`);
    expect(res.ok()).toBeTruthy();

    const data = await res.json();
    expect(data.data).toBeInstanceOf(Array);
    expect(data.data.length).toBeGreaterThan(0);

    const groqProvider = data.data.find((p: { name: string }) => p.name === 'groq');
    expect(groqProvider).toBeDefined();
    expect(groqProvider.default_model).toBe('openai/gpt-oss-20b');
  });

  test('3. complete onboarding', async ({ request }) => {
    const res = await request.post(`http://${ctx.host}:${ctx.port}/api/v1/onboard/complete`);
    expect(res.ok()).toBeTruthy();

    const data = await res.json();
    expect(data.data.status).toBe('completed');
  });

  test('4. multi-turn text conversation via WebSocket', async ({ page }) => {
    // Simple text conversation without tool calls
    const result = await page.evaluate(
      async ({ host, port }) => {
        return new Promise<{
          turns: Array<{ sent: string; received: string | null; error: string | null }>;
          chatId: string | null;
        }>((resolve) => {
          const ws = new WebSocket(`ws://${host}:${port}/ws/chat`);
          let chatId: string | null = null;
          let currentTurn = 0;
          // Simple conversational messages - tell model to just respond with text
          const turns = [
            { sent: 'Say "Hello" in one word. Do not use any tools.', received: null, error: null },
            { sent: 'Say "Yes" in one word. Do not use any tools.', received: null, error: null },
            { sent: 'Say "Goodbye" in one word. Do not use any tools.', received: null, error: null },
          ];

          const timeout = setTimeout(() => {
            ws.close();
            resolve({ turns, chatId });
          }, 90000);

          ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);

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
                }, 500);
              } else {
                clearTimeout(timeout);
                setTimeout(() => {
                  ws.close();
                  resolve({ turns, chatId });
                }, 1000);
              }
            }

            if (msg.type === 'error') {
              turns[currentTurn].error = msg.error;
              clearTimeout(timeout);
              ws.close();
              resolve({ turns, chatId });
            }
          };

          ws.onerror = () => {
            clearTimeout(timeout);
            resolve({ turns, chatId });
          };
        });
      },
      { host: ctx.host, port: ctx.port }
    );

    console.log('Conversation result:', JSON.stringify(result, null, 2));

    expect(result.chatId).toBeTruthy();

    for (let i = 0; i < result.turns.length; i++) {
      const turn = result.turns[i];
      expect(turn.error, `Turn ${i + 1} error`).toBeNull();
      expect(turn.received, `Turn ${i + 1} response`).toBeTruthy();
    }
  });

  test('5. verify history files created', async () => {
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
    expect(lines.length).toBeGreaterThanOrEqual(2);

    const records = lines.map((line) => JSON.parse(line));
    const types = records.map((r) => r.type);

    expect(types).toContain('session_meta');
    expect(types).toContain('user_message');
    expect(types).toContain('assistant_message');

    console.log('History record types:', types);
  });
});
