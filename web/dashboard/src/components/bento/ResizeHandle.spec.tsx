/**
 * ResizeHandle tests.
 *
 * Verifies:
 * 1. The SVG path draws a 」shape (bottom-right corner), not 「(top-right)
 * 2. The handle is a bare corner indicator without a background box
 * 3. The curve radius matches the card's border-radius (--mk-radius-xl = 24px)
 */
import { render, screen } from '@testing-library/react';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import { ResizeHandle } from './ResizeHandle';

/**
 * Parse an SVG path d-attribute into points with their final x, y coordinates.
 * Handles formats like "M4 1 L12 1 Q13 1 13 2 L13 10" (space-separated).
 */
function parsePathEndpoints(d: string): Array<{ cmd: string; x: number; y: number }> {
  const points: Array<{ cmd: string; x: number; y: number }> = [];
  // Split into command groups: each starts with a letter
  const parts = d.match(/[A-Za-z][^A-Za-z]*/g) ?? [];
  for (const part of parts) {
    const cmd = part[0]!;
    const nums = part.slice(1).trim().split(/[\s,]+/).map(Number).filter((n) => !isNaN(n));
    // Take the last two numbers as the endpoint x, y
    if (nums.length >= 2) {
      points.push({ cmd, x: nums[nums.length - 2]!, y: nums[nums.length - 1]! });
    }
  }
  return points;
}

const defaultProps = {
  blockId: 'test-block',
  currentSize: '1x1' as const,
  columns: 4,
  onResize: vi.fn(),
};

describe('ResizeHandle', () => {
  it('renders an SVG path', () => {
    render(<ResizeHandle {...defaultProps} />);
    const path = document.querySelector('svg path');
    expect(path).not.toBeNull();
    expect(path!.getAttribute('d')).toBeTruthy();
  });

  describe('SVG path direction: must be 」(bottom-right corner)', () => {
    it('path endpoint is in the bottom-left region (line goes left at bottom)', () => {
      render(<ResizeHandle {...defaultProps} />);
      const d = document.querySelector('svg path')!.getAttribute('d')!;
      const segments = parsePathEndpoints(d);
      expect(segments.length).toBeGreaterThanOrEqual(2);

      // The final segment should move leftward (decreasing x) at a high y value
      // This is the horizontal bar of 」going left at the bottom
      const last = segments[segments.length - 1]!;
      const first = segments[0]!;

      // 」shape: starts high (low y), ends low (high y) and left (low x)
      // First point should have high x (right side)
      // Last point should have low x (left side) and high y (bottom)
      expect(last.x).toBeLessThan(first.x); // endpoint is left of start
      expect(last.y).toBeGreaterThan(first.y); // endpoint is below start
    });

    it('path does NOT form a 「shape (top-right corner going right-then-down)', () => {
      render(<ResizeHandle {...defaultProps} />);
      const d = document.querySelector('svg path')!.getAttribute('d')!;
      const segments = parsePathEndpoints(d);
      const last = segments[segments.length - 1]!;
      const first = segments[0]!;

      // 「shape would have: first.y low, last.y high, last.x >= first.x
      // If last.x > first.x, it's going rightward — that's 「not 」
      const isTopRightCorner = last.x >= first.x && last.y > first.y;
      expect(isTopRightCorner).toBe(false);
    });
  });

  describe('Corner affordance: no background box', () => {
    it('handle element has no background styling (bare corner indicator)', () => {
      render(<ResizeHandle {...defaultProps} />);
      const handle = document.querySelector('[title="Drag to resize"]') as HTMLElement;
      expect(handle).not.toBeNull();
      // Should not have a visible background (transparent or none)
      const bg = handle.style.background || handle.style.backgroundColor;
      expect(bg === '' || bg === 'transparent' || bg === 'none').toBe(true);
    });
  });

  describe('Curve radius matches card border-radius', () => {
    /** Card border-radius from --mk-radius-xl in variables.css */
    const CARD_RADIUS = 24;

    it('Q-bezier radius equals --mk-radius-xl (24px)', () => {
      render(<ResizeHandle {...defaultProps} />);
      const d = document.querySelector('svg path')!.getAttribute('d')!;

      // Extract the Q command: Q cx cy x2 y2
      const qMatch = d.match(/Q\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)/);
      expect(qMatch).not.toBeNull();

      const [, cxStr, cyStr, exStr, eyStr] = qMatch!;
      const cx = Number(cxStr);
      const cy = Number(cyStr);
      const ex = Number(exStr);
      const ey = Number(eyStr);

      // The L command before Q gives the curve start point
      const lMatch = d.match(/L\s*([\d.]+)\s+([\d.]+)\s+Q/);
      expect(lMatch).not.toBeNull();
      const sx = Number(lMatch![1]);
      const sy = Number(lMatch![2]);

      // Vertical radius: control_y - start_y
      const verticalRadius = cy - sy;
      // Horizontal radius: control_x - end_x
      const horizontalRadius = cx - ex;

      expect(verticalRadius).toBe(CARD_RADIUS);
      expect(horizontalRadius).toBe(CARD_RADIUS);
    });

    it('--mk-radius-xl in variables.css is 24px', () => {
      const css = readFileSync(
        resolve(__dirname, '../../styles/variables.css'),
        'utf-8',
      );
      const match = css.match(/--mk-radius-xl:\s*([\d.]+)px/);
      expect(match).not.toBeNull();
      expect(Number(match![1])).toBe(CARD_RADIUS);
    });
  });
});
