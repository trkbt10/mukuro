import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

const MUKURO_HOST = process.env.MUKURO_HOST ?? 'localhost';
const MUKURO_PORT = process.env.MUKURO_PORT ?? '6960';
const HISTORY_DIR = path.join(
  os.homedir(),
  'Library/Application Support/mukuro/history'
);

/**
 * Count JSONL history files in the history directory.
 */
function countHistoryFiles(): number {
  try {
    let count = 0;
    const walk = (dir: string) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full);
        else if (entry.name.endsWith('.jsonl')) count++;
      }
    };
    if (fs.existsSync(HISTORY_DIR)) walk(HISTORY_DIR);
    return count;
  } catch {
    return 0;
  }
}

/**
 * Find history files created in the last N seconds.
 */
function findRecentHistoryFiles(withinSeconds: number): string[] {
  const result: string[] = [];
  const now = Date.now();
  const walk = (dir: string) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith('.jsonl')) {
        const stat = fs.statSync(full);
        if (now - stat.mtimeMs < withinSeconds * 1000) {
          result.push(full);
        }
      }
    }
  };
  if (fs.existsSync(HISTORY_DIR)) walk(HISTORY_DIR);
  return result;
}

test.describe('WebSocket Chat E2E', () => {
  test.skip(
    !process.env.MUKURO_BACKEND_RUNNING,
    'Requires MUKURO_BACKEND_RUNNING=1 and backend at ws://localhost:6960'
  );

  test('connects to backend WebSocket, receives session, and creates history', async ({
    page,
  }) => {
    const filesBefore = countHistoryFiles();

    // Navigate to chat page
    await page.goto('/chat');

    // Wait for WebSocket connection indicator or chat input
    const chatInput = page.locator('textarea, input[type="text"]').first();
    await expect(chatInput).toBeVisible({ timeout: 10000 });

    // Send a test message
    await chatInput.fill('Hello from E2E test');
    await chatInput.press('Enter');

    // Wait for assistant response (look for "Mukuro" label in message)
    const assistantMessage = page.locator('text=Mukuro').first();
    await expect(assistantMessage).toBeVisible({ timeout: 30000 });

    // Wait for history to be flushed
    await page.waitForTimeout(2000);

    // Check history file was created
    const filesAfter = countHistoryFiles();
    expect(filesAfter).toBeGreaterThan(filesBefore);

    // Verify recent history file contains expected records
    const recentFiles = findRecentHistoryFiles(60);
    expect(recentFiles.length).toBeGreaterThan(0);

    const content = fs.readFileSync(recentFiles[0], 'utf-8');
    const lines = content.trim().split('\n').filter(Boolean);
    expect(lines.length).toBeGreaterThanOrEqual(2); // At least session_meta + user_message

    const records = lines.map((line) => JSON.parse(line));
    const types = records.map((r) => r.type);
    expect(types).toContain('session_meta');
    expect(types).toContain('user_message');
  });
});

test.describe('WebSocket Chat (raw WebSocket)', () => {
  test.skip(
    !process.env.MUKURO_BACKEND_RUNNING,
    'Requires MUKURO_BACKEND_RUNNING=1 and backend at ws://localhost:6960'
  );

  /**
   * 回帰テスト: 純粋テキスト会話の継続
   * シナリオ: User1 → Assistant1 → User2 → Assistant2
   * バグ: 2ターン目で ModelCallFailed が発生していた
   */
  test('two-turn text-only conversation continuation', async ({ page }) => {
    // Use page.evaluate to test WebSocket with multiple turns
    const result = await page.evaluate(
      async ({ host, port }) => {
        return new Promise<{
          turn1: { sent: string; received: string | null; error: string | null };
          turn2: { sent: string; received: string | null; error: string | null };
          chatId: string | null;
        }>((resolve) => {
          const ws = new WebSocket(`ws://${host}:${port}/ws/chat`);
          let chatId: string | null = null;
          let currentTurn = 0;
          const turns: Array<{ sent: string; received: string | null; error: string | null }> = [
            { sent: 'ブースとラプう', received: null, error: null },
            { sent: 'bootstrapって完了した？', received: null, error: null },
          ];

          const timeout = setTimeout(() => {
            ws.close();
            resolve({
              turn1: turns[0],
              turn2: turns[1],
              chatId,
            });
          }, 60000);

          ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);

            if (msg.type === 'session') {
              chatId = msg.chat_id;
              // Send first message
              ws.send(JSON.stringify({ type: 'send', content: turns[0].sent }));
            }

            if (msg.type === 'message' && msg.role === 'assistant') {
              turns[currentTurn].received = msg.content;
              currentTurn++;

              if (currentTurn < turns.length) {
                // Send next message after a short delay
                setTimeout(() => {
                  ws.send(JSON.stringify({ type: 'send', content: turns[currentTurn].sent }));
                }, 500);
              } else {
                // All turns completed
                clearTimeout(timeout);
                setTimeout(() => {
                  ws.close();
                  resolve({
                    turn1: turns[0],
                    turn2: turns[1],
                    chatId,
                  });
                }, 1000);
              }
            }

            if (msg.type === 'error') {
              turns[currentTurn].error = msg.error;
              clearTimeout(timeout);
              ws.close();
              resolve({
                turn1: turns[0],
                turn2: turns[1],
                chatId,
              });
            }
          };

          ws.onerror = () => {
            clearTimeout(timeout);
            resolve({
              turn1: turns[0],
              turn2: turns[1],
              chatId,
            });
          };
        });
      },
      { host: MUKURO_HOST, port: MUKURO_PORT }
    );

    // Verify both turns succeeded
    console.log('Turn 1:', result.turn1);
    console.log('Turn 2:', result.turn2);

    expect(result.chatId).toBeTruthy();

    // Turn 1 should succeed
    expect(result.turn1.error).toBeNull();
    expect(result.turn1.received).toBeTruthy();

    // Turn 2 should also succeed (this was the failing case)
    expect(result.turn2.error).toBeNull();
    expect(result.turn2.received).toBeTruthy();
  });

  test('raw WebSocket connection creates history file', async ({ page }) => {
    const filesBefore = countHistoryFiles();

    // Use page.evaluate to test WebSocket directly from browser context
    const result = await page.evaluate(
      async ({ host, port }) => {
        return new Promise<{
          sessionReceived: boolean;
          chatId: string | null;
          messageReceived: boolean;
          error: string | null;
        }>((resolve) => {
          const ws = new WebSocket(`ws://${host}:${port}/ws/chat`);
          let chatId: string | null = null;
          let messageReceived = false;

          const timeout = setTimeout(() => {
            ws.close();
            resolve({
              sessionReceived: !!chatId,
              chatId,
              messageReceived,
              error: 'Timeout',
            });
          }, 15000);

          ws.onopen = () => {
            // Wait for session message
          };

          ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);

            if (msg.type === 'session') {
              chatId = msg.chat_id;
              // Send a test message
              ws.send(JSON.stringify({ type: 'send', content: 'E2E test message' }));
            }

            if (msg.type === 'message' && msg.role === 'assistant') {
              messageReceived = true;
              setTimeout(() => {
                clearTimeout(timeout);
                ws.close();
                resolve({
                  sessionReceived: true,
                  chatId,
                  messageReceived: true,
                  error: null,
                });
              }, 1000);
            }

            if (msg.type === 'error') {
              clearTimeout(timeout);
              ws.close();
              resolve({
                sessionReceived: !!chatId,
                chatId,
                messageReceived,
                error: msg.error,
              });
            }
          };

          ws.onerror = () => {
            clearTimeout(timeout);
            resolve({
              sessionReceived: !!chatId,
              chatId,
              messageReceived,
              error: 'WebSocket error',
            });
          };
        });
      },
      { host: MUKURO_HOST, port: MUKURO_PORT }
    );

    expect(result.error).toBeNull();
    expect(result.sessionReceived).toBe(true);
    expect(result.chatId).toBeTruthy();
    expect(result.messageReceived).toBe(true);

    // Wait for history to be flushed
    await page.waitForTimeout(2000);

    // Verify history file created
    const filesAfter = countHistoryFiles();
    expect(filesAfter).toBeGreaterThan(filesBefore);
  });
});
