/**
 * Scroll chain structural test.
 *
 * Verifies the CSS overflow chain from Layout → page allows vertical scrolling.
 * A flex column with overflow: hidden must have min-height: 0 on flex children
 * for nested overflow-y: auto to work.
 *
 * This test reads raw CSS files to prevent regressions where a CSS change
 * silently breaks scrolling (which requires browser verification to catch otherwise).
 */
import { readFileSync } from 'fs';
import { resolve } from 'path';

function readCss(relativePath: string): string {
  return readFileSync(resolve(__dirname, relativePath), 'utf-8');
}

/** Extract all rule blocks for a given selector from raw CSS */
function extractRules(css: string, selector: string): string {
  // Remove comments
  const clean = css.replace(/\/\*[\s\S]*?\*\//g, '');
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(`${escaped}\\s*\\{([^}]*)\\}`, 'g');
  const blocks: string[] = [];
  let m: RegExpExecArray | null;
  while ((m = re.exec(clean)) !== null) {
    blocks.push(m[1]!);
  }
  return blocks.join('\n');
}

function hasProperty(block: string, prop: string, value?: string): boolean {
  const lines = block.split('\n').map((l) => l.trim()).filter(Boolean);
  return lines.some((line) => {
    if (!line.includes(prop)) return false;
    if (value === undefined) return true;
    return line.includes(value);
  });
}

describe('Scroll chain: Layout → page', () => {
  const layoutCss = readCss('./Layout.module.css');
  const pageCss = readCss('../../styles/page.module.css');

  describe('Layout .main', () => {
    const main = extractRules(layoutCss, '.main');

    it('is a flex column', () => {
      expect(hasProperty(main, 'display', 'flex')).toBe(true);
      expect(hasProperty(main, 'flex-direction', 'column')).toBe(true);
    });

    it('has height: 100% to fill panel', () => {
      expect(hasProperty(main, 'height', '100%')).toBe(true);
    });
  });

  describe('Layout .content', () => {
    const content = extractRules(layoutCss, '.content');

    it('is a flex item that fills remaining space', () => {
      expect(hasProperty(content, 'flex', '1')).toBe(true);
    });

    it('has min-height: 0 to allow shrinking (critical for scroll)', () => {
      expect(hasProperty(content, 'min-height', '0')).toBe(true);
    });

    it('has overflow-y: auto (NOT hidden — hidden blocks child scroll)', () => {
      expect(hasProperty(content, 'overflow-y', 'auto')).toBe(true);
      expect(hasProperty(content, 'overflow', 'hidden')).toBe(false);
    });
  });

  describe('Shared page shell', () => {
    const page = extractRules(pageCss, '.page');

    it('has overflow-y: auto for vertical scrolling', () => {
      expect(hasProperty(page, 'overflow-y', 'auto')).toBe(true);
    });

    it('has height: 100% to fill .content', () => {
      expect(hasProperty(page, 'height', '100%')).toBe(true);
    });
  });
});
