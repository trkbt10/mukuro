import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { spawn, ChildProcess } from 'child_process';
import { fileURLToPath } from 'url';

/**
 * Harmony Streaming Translation E2E Test
 *
 * Tests the streaming translation layer:
 * 1. Start mukuro with use_responses_api: true (translation mode)
 * 2. Send message with "send_stream" type
 * 3. Verify Responses API events are received (response.created, response.output_text.delta, etc.)
 * 4. Verify translation layer is used (HarmonyToResponsesTranslator)
 *
 * Prerequisites:
 * - mukuro binary built: ./scripts/build-native.sh
 * - Run with: GROQ_API_KEY=<key> npx playwright test e2e/harmony-streaming.spec.ts
 */

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const MUKURO_BINARY = path.join(__dirname, '../../../_build/native/debug/build/mukuro.exe');
const GROQ_API_KEY = process.env.GROQ_API_KEY;
const TEST_PORT = 6964;

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

  // Create config.json with Groq provider using Responses API (translation mode)
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
          // use_responses_api: true triggers translation layer for Groq
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

test.describe.serial('Harmony Streaming Translation E2E', () => {
  test.skip(!GROQ_API_KEY, 'Requires GROQ_API_KEY environment variable');

  test.beforeAll(async () => {
    ctx = {
      tmpDir: fs.mkdtempSync(path.join(os.tmpdir(), 'mukuro-streaming-test-')),
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

  test('1. verify Responses API translation mode configured', async ({ request }) => {
    const res = await request.get(`http://${ctx.host}:${ctx.port}/api/v1/settings/providers`);
    expect(res.ok()).toBeTruthy();

    const data = await res.json();
    const groqProvider = data.data.find((p: { name: string }) => p.name === 'groq');
    expect(groqProvider).toBeDefined();
    // use_responses_api: true with Groq triggers translation
    expect(groqProvider.use_responses_api).toBe(true);
    expect(groqProvider.base_url).toContain('groq');
  });

  test('2. complete onboarding', async ({ request }) => {
    const res = await request.post(`http://${ctx.host}:${ctx.port}/api/v1/onboard/complete`);
    expect(res.ok()).toBeTruthy();
  });

  test('3. streaming with Responses API events (translation layer)', async ({ page }) => {
    const result = await page.evaluate(
      async ({ host, port }) => {
        return new Promise<{
          chatId: string | null;
          streamEvents: Array<{ type: string; event?: string; data?: unknown }>;
          finalMessage: string | null;
          error: string | null;
        }>((resolve) => {
          const ws = new WebSocket(`ws://${host}:${port}/ws/chat`);
          let chatId: string | null = null;
          const streamEvents: Array<{ type: string; event?: string; data?: unknown }> = [];
          let finalMessage: string | null = null;
          let error: string | null = null;

          const timeout = setTimeout(() => {
            ws.close();
            resolve({ chatId, streamEvents, finalMessage, error: 'timeout' });
          }, 60000);

          ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);

            if (msg.type === 'session') {
              chatId = msg.chat_id;
              // Send with streaming mode
              ws.send(JSON.stringify({ type: 'send_stream', content: 'What is the current time?' }));
            }

            // Capture stream events (Responses API format)
            if (msg.type === 'stream') {
              streamEvents.push({
                type: msg.type,
                event: msg.event,
                data: msg.data,
              });
            }

            // Capture final message
            if (msg.type === 'message' && msg.role === 'assistant') {
              finalMessage = msg.content;
              clearTimeout(timeout);
              setTimeout(() => {
                ws.close();
                resolve({ chatId, streamEvents, finalMessage, error });
              }, 500);
            }

            if (msg.type === 'error') {
              error = msg.error;
              clearTimeout(timeout);
              ws.close();
              resolve({ chatId, streamEvents, finalMessage, error });
            }
          };

          ws.onerror = () => {
            clearTimeout(timeout);
            resolve({ chatId, streamEvents, finalMessage, error: 'websocket error' });
          };
        });
      },
      { host: ctx.host, port: ctx.port }
    );

    console.log('Stream events received:', JSON.stringify(result.streamEvents, null, 2));
    console.log('Final message:', result.finalMessage);

    expect(result.chatId).toBeTruthy();
    expect(result.error).toBeNull();
    expect(result.finalMessage).toBeTruthy();

    // Verify Responses API events were received (translation layer output)
    const eventTypes = result.streamEvents.map((e) => e.event);
    console.log('Event types:', eventTypes);

    // Should have response.created event
    expect(eventTypes).toContain('response.created');

    // Should have either text or function call events
    const hasTextEvents =
      eventTypes.includes('response.output_text.delta') || eventTypes.includes('response.output_text.done');
    const hasFunctionEvents = eventTypes.includes('response.output_item.added');
    expect(hasTextEvents || hasFunctionEvents).toBe(true);

    // Should have response.completed event
    expect(eventTypes).toContain('response.completed');
  });

  test('4. verify multi-turn streaming maintains context', async ({ page }) => {
    const result = await page.evaluate(
      async ({ host, port }) => {
        return new Promise<{
          turns: Array<{ sent: string; events: string[]; response: string | null }>;
          chatId: string | null;
          error: string | null;
        }>((resolve) => {
          const ws = new WebSocket(`ws://${host}:${port}/ws/chat`);
          let chatId: string | null = null;
          let currentTurn = 0;
          let error: string | null = null;

          const turns = [
            { sent: 'What is 2 + 2?', events: [] as string[], response: null as string | null },
            { sent: 'Multiply that by 3', events: [] as string[], response: null as string | null },
          ];

          const timeout = setTimeout(() => {
            ws.close();
            resolve({ turns, chatId, error: 'timeout' });
          }, 120000);

          ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);

            if (msg.type === 'session') {
              chatId = msg.chat_id;
              ws.send(JSON.stringify({ type: 'send_stream', content: turns[0].sent }));
            }

            // Capture stream events for current turn
            if (msg.type === 'stream' && msg.event) {
              turns[currentTurn].events.push(msg.event);
            }

            if (msg.type === 'message' && msg.role === 'assistant') {
              turns[currentTurn].response = msg.content;
              currentTurn++;

              if (currentTurn < turns.length) {
                setTimeout(() => {
                  ws.send(JSON.stringify({ type: 'send_stream', content: turns[currentTurn].sent }));
                }, 1000);
              } else {
                clearTimeout(timeout);
                setTimeout(() => {
                  ws.close();
                  resolve({ turns, chatId, error });
                }, 500);
              }
            }

            if (msg.type === 'error') {
              error = msg.error;
              clearTimeout(timeout);
              ws.close();
              resolve({ turns, chatId, error });
            }
          };

          ws.onerror = () => {
            clearTimeout(timeout);
            resolve({ turns, chatId, error: 'websocket error' });
          };
        });
      },
      { host: ctx.host, port: ctx.port }
    );

    console.log('Multi-turn streaming results:', JSON.stringify(result.turns, null, 2));

    expect(result.chatId).toBeTruthy();
    expect(result.error).toBeNull();

    // Both turns should have responses
    expect(result.turns[0].response).toBeTruthy();
    expect(result.turns[1].response).toBeTruthy();

    // Both turns should have received Responses API events
    for (const turn of result.turns) {
      expect(turn.events).toContain('response.created');
      expect(turn.events).toContain('response.completed');
    }

    // Turn 2 should demonstrate context awareness (result of 2+2=4 multiplied by 3)
    const turn2Response = result.turns[1].response?.toLowerCase() || '';
    // Should mention 12 (4 * 3) or reference the previous calculation
    expect(turn2Response.includes('12') || turn2Response.includes('4') || turn2Response.includes('three')).toBe(true);
  });
});
