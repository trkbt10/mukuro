import { test, expect } from '@playwright/test';

test.describe('Dashboard scroll', () => {
  test('page scrolls vertically when content overflows viewport', async ({ page }) => {
    await page.goto('/dashboard');

    const main = page.locator('main');
    await expect(main).toBeVisible({ timeout: 10000 });

    // Inject tall content inside the page to force overflow
    const injected = await main.evaluate((el) => {
      const target = el.firstElementChild ?? el;
      const spacer = document.createElement('div');
      spacer.style.height = '10000px';
      target.appendChild(spacer);
      return target.tagName;
    });

    // Find the actual scrollable element (main or its first child)
    const scrolled = await main.evaluate((el) => {
      // Try the page div first (first child of main), then main itself
      const candidates = [el.firstElementChild, el].filter(Boolean) as Element[];
      for (const c of candidates) {
        c.scrollTop = 500;
        if (c.scrollTop > 0) return { element: c.tagName, scrollTop: c.scrollTop };
      }
      return { element: 'none', scrollTop: 0 };
    });

    expect(scrolled.scrollTop).toBeGreaterThan(0);
  });
});
