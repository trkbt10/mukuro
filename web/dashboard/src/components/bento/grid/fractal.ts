/**
 * Fractal Grid System — ported from zakoducthunt bento-grid.
 *
 * Maintains CELL:GAP = 12:1 ratio at every nesting level.
 *
 * Level 0: CELL=144, GAP=12  (ratio 12:1)
 * Level 1: CELL=69.12, GAP=5.76  (ratio 12:1)
 * Level 2: CELL=33.18, GAP=2.76  (ratio 12:1)
 */

export type BentoSize = '1x1' | '2x1' | '1x2' | '2x2' | '3x1' | '4x1';

// ── Constants ──

export const CELL = 144;
export const GAP = 12;
export const RATIO = CELL / GAP; // 12

export const ICON = { sm: 36, md: 48, lg: 72 } as const;

export const SPACE = {
  xs: GAP * 0.5,  // 6
  sm: GAP,        // 12
  md: GAP * 2,    // 24
  lg: GAP * 3,    // 36
  xl: GAP * 4,    // 48
} as const;

// ── Types ──

export type Rect = { x: number; y: number; w: number; h: number };

export type Grid = {
  width: number;
  height: number;
  cells: Rect[];
  cols: number;
  rows: number;
  gap: number;
};

export type SplitResult = {
  cells: Rect[];
  gapX: number;
  gapY: number;
};

// ── Size parsing ──

function parseSize(size: BentoSize): { cols: number; rows: number } {
  const [c, r] = size.split('x').map(Number);
  return { cols: c!, rows: r! };
}

// ── ViewBox ──

export function viewBoxSize(size: BentoSize): { w: number; h: number } {
  const { cols, rows } = parseSize(size);
  return {
    w: cols * CELL + (cols - 1) * GAP,
    h: rows * CELL + (rows - 1) * GAP,
  };
}

// ── Grid creation ──

export function createGrid(size: BentoSize): Grid {
  const { cols, rows } = parseSize(size);
  const width = cols * CELL + (cols - 1) * GAP;
  const height = rows * CELL + (rows - 1) * GAP;
  const cells: Rect[] = [];

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      cells.push({
        x: c * (CELL + GAP),
        y: r * (CELL + GAP),
        w: CELL,
        h: CELL,
      });
    }
  }

  return { width, height, cells, cols, rows, gap: GAP };
}

// ── Rect utilities ──

export function fullRect(grid: Grid): Rect {
  return { x: 0, y: 0, w: grid.width, h: grid.height };
}

export function insetRect(rect: Rect, padding: number): Rect {
  return {
    x: rect.x + padding,
    y: rect.y + padding,
    w: rect.w - padding * 2,
    h: rect.h - padding * 2,
  };
}

export function rectCenter(rect: Rect): { cx: number; cy: number } {
  return { cx: rect.x + rect.w / 2, cy: rect.y + rect.h / 2 };
}

// ── Fractal splitting ──
// Subdivide a rect maintaining CELL:GAP ratio at each level.

export function splitH(rect: Rect, n: number): SplitResult {
  if (n <= 0) return { cells: [], gapX: 0, gapY: 0 };
  if (n === 1) return { cells: [rect], gapX: 0, gapY: 0 };

  // Solve: cellW × n + gapX × (n-1) = rect.w
  // where: gapX = cellW / RATIO
  const cellW = (rect.w * CELL) / (n * CELL + (n - 1) * GAP);
  const gapX = cellW / RATIO;
  const cells: Rect[] = [];

  for (let i = 0; i < n; i++) {
    cells.push({
      x: rect.x + i * (cellW + gapX),
      y: rect.y,
      w: cellW,
      h: rect.h,
    });
  }

  return { cells, gapX, gapY: 0 };
}

export function splitV(rect: Rect, n: number): SplitResult {
  if (n <= 0) return { cells: [], gapX: 0, gapY: 0 };
  if (n === 1) return { cells: [rect], gapX: 0, gapY: 0 };

  const cellH = (rect.h * CELL) / (n * CELL + (n - 1) * GAP);
  const gapY = cellH / RATIO;
  const cells: Rect[] = [];

  for (let i = 0; i < n; i++) {
    cells.push({
      x: rect.x,
      y: rect.y + i * (cellH + gapY),
      w: rect.w,
      h: cellH,
    });
  }

  return { cells, gapX: 0, gapY };
}

// ── Placement ──

export type HAlign = 'left' | 'center' | 'right';
export type VAlign = 'top' | 'center' | 'bottom';
export type Alignment = { horizontal?: HAlign; vertical?: VAlign };

export type Placement = {
  x: number;
  y: number;
  width: number;
  height: number;
};

export function place(params: {
  zone: Rect;
  width: number;
  height: number;
  align?: Alignment;
}): Placement {
  const { zone, width, height, align } = params;
  const h = align?.horizontal ?? 'center';
  const v = align?.vertical ?? 'center';

  let x: number;
  if (h === 'left') x = zone.x;
  else if (h === 'right') x = zone.x + zone.w - width;
  else x = zone.x + (zone.w - width) / 2;

  let y: number;
  if (v === 'top') y = zone.y;
  else if (v === 'bottom') y = zone.y + zone.h - height;
  else y = zone.y + (zone.h - height) / 2;

  return { x, y, width, height };
}

export function centerOf(p: Placement): { cx: number; cy: number } {
  return { cx: p.x + p.width / 2, cy: p.y + p.height / 2 };
}

// ── Convenience: content area for a block size ──

export function contentArea(size: BentoSize): Rect {
  const grid = createGrid(size);
  return insetRect(fullRect(grid), GAP);
}

export function contentZones(size: BentoSize): { cr: Rect; top: Rect; bottom: Rect } {
  const cr = contentArea(size);
  const split = splitV(cr, 2);
  return { cr, top: split.cells[0]!, bottom: split.cells[1]! };
}
