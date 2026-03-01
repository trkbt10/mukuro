import { test, expect } from '@playwright/test';

test.describe('Panel Layout', () => {
  test('Plugins page has stat cards in statGrid', async ({ page }) => {
    await page.goto('/plugins');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // StatGrid should contain 3 ContentPanels
    const statGrid = page.locator('[class*="statGrid"]');
    await expect(statGrid).toBeVisible();

    // Check grid has proper gap
    const gap = await statGrid.evaluate((el) => getComputedStyle(el).gap);
    console.log('StatGrid gap:', gap);
    expect(gap).toBe('12px'); // --mk-space-lg
  });

  test('Plugin detail page has 2-column panelGrid layout', async ({ page }) => {
    await page.goto('/plugins/builtin');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Check grid layout via CSS
    const grid = page.locator('[class*="grid"]').first();
    await expect(grid).toBeVisible();

    const gridTemplateColumns = await grid.evaluate(
      (el) => getComputedStyle(el).gridTemplateColumns
    );
    console.log('Grid columns:', gridTemplateColumns);
    // Should be 2 columns (e.g., "524px 524px" or similar)
    expect(gridTemplateColumns.split(' ').length).toBe(2);
  });

  test('Context detail page has PanelSection with border', async ({ page }) => {
    await page.goto('/context/soul');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Find panel by checking for border style
    const panels = page.locator('main > div > div');
    let foundPanel = false;

    for (let i = 0; i < await panels.count(); i++) {
      const panel = panels.nth(i);
      const border = await panel.evaluate((el) => getComputedStyle(el).border);
      if (border.includes('1px')) {
        console.log('Found panel with border:', border);
        foundPanel = true;
        break;
      }
    }

    expect(foundPanel).toBe(true);
  });

  test('Settings detail page has PanelSection with form fields', async ({ page }) => {
    await page.goto('/settings/retry');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Check that inputs exist
    const inputs = main.locator('input');
    const inputCount = await inputs.count();
    console.log('Input count:', inputCount);
    expect(inputCount).toBeGreaterThanOrEqual(1);
  });

  test('plugin list has proper row styling', async ({ page }) => {
    await page.goto('/plugins');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Plugin list should have border-radius
    const pluginList = page.locator('[class*="pluginList"]');
    if (await pluginList.isVisible()) {
      const borderRadius = await pluginList.evaluate(
        (el) => getComputedStyle(el).borderRadius
      );
      console.log('Plugin list border radius:', borderRadius);
      expect(borderRadius).toBe('20px'); // --mk-radius-lg
    }
  });
});
