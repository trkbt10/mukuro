import { test, expect } from '@playwright/test';

test.describe('PageToolbar', () => {
  test('toolbar has adequate height on Context page (top-level)', async ({ page }) => {
    await page.goto('/context');

    // Wait for page to load
    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Find the toolbar (class contains "toolbar" from CSS module)
    const toolbar = page.locator('[class*="toolbar"]').first();
    await expect(toolbar).toBeVisible();

    // Check toolbar dimensions
    const box = await toolbar.boundingBox();
    console.log('Toolbar dimensions:', box);

    // Toolbar should have minimum height of 44px (comfortable touch target)
    expect(box?.height).toBeGreaterThanOrEqual(44);
  });

  test('toolbar title is visible and not truncated on Context page', async ({ page }) => {
    await page.goto('/context');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Check that title is visible
    const title = page.locator('h1:has-text("Context")');
    await expect(title).toBeVisible();

    // Title should not be clipped
    const titleBox = await title.boundingBox();
    console.log('Title dimensions:', titleBox);
    expect(titleBox?.height).toBeGreaterThan(0);
  });

  test('toolbar has adequate height on Plugins page', async ({ page }) => {
    await page.goto('/plugins');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Find the toolbar - look for react-editor-ui Toolbar or our wrapper
    const toolbar = page.locator('[class*="toolbar"]').first();
    await expect(toolbar).toBeVisible();

    const box = await toolbar.boundingBox();
    console.log('Plugins toolbar dimensions:', box);

    // Toolbar should have minimum height
    expect(box?.height).toBeGreaterThanOrEqual(44);
  });

  test('subtitle is visible when present', async ({ page }) => {
    await page.goto('/plugins');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Check subtitle exists and is visible
    const subtitle = page.locator('p:has-text("Manage installed plugins")');
    await expect(subtitle).toBeVisible();

    const subtitleBox = await subtitle.boundingBox();
    console.log('Subtitle dimensions:', subtitleBox);
    expect(subtitleBox?.height).toBeGreaterThan(0);
  });

  test('Chat page toolbar has correct height', async ({ page }) => {
    await page.goto('/chat');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    const toolbar = page.locator('[class*="toolbar"]').first();
    const box = await toolbar.boundingBox();
    console.log('Chat toolbar dimensions:', box);
    expect(box?.height).toBe(56);
  });

  test('History page toolbar has correct height', async ({ page }) => {
    await page.goto('/history');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    const toolbar = page.locator('[class*="toolbar"]').first();
    const box = await toolbar.boundingBox();
    console.log('History toolbar dimensions:', box);
    expect(box?.height).toBe(56);
  });

  test('detail page toolbar has back button and adequate height', async ({ page }) => {
    // Navigate to a context detail page
    await page.goto('/context/soul');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Check back button exists
    const backButton = page.locator('button[aria-label="Back"]');
    await expect(backButton).toBeVisible();

    // Check toolbar has adequate height
    const toolbar = page.locator('[class*="toolbar"]').first();
    const box = await toolbar.boundingBox();
    console.log('Detail page toolbar dimensions:', box);
    expect(box?.height).toBeGreaterThanOrEqual(44);

    // Check title is visible (should be the filename)
    const title = page.locator('h1');
    await expect(title).toBeVisible();
  });
});
