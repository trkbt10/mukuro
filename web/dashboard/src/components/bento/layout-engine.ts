import type { BentoSize } from './grid/fractal';
import { type DashboardBlock, type BlockPosition, sizeSpan, DEFAULT_DASHBOARD_BLOCKS } from './layout-types';

// ── Helpers ──

/** Clamp a block size so its col span fits within `columns` */
function effectiveSize(size: BentoSize, columns: number): BentoSize {
  const { cols } = sizeSpan(size);
  if (cols <= columns) return size;
  return `${columns}x${size.split('x')[1]}` as BentoSize;
}

// ── Grid cell queries ──

/** Check if a specific cell (col, row) is occupied by any block */
function isCellOccupied(
  blocks: DashboardBlock[],
  col: number,
  row: number,
  columns: number,
  excludeId?: string,
): boolean {
  for (const b of blocks) {
    if (b.id === excludeId) continue;
    const { cols, rows } = sizeSpan(effectiveSize(b.size, columns));
    if (
      col >= b.position.col &&
      col < b.position.col + cols &&
      row >= b.position.row &&
      row < b.position.row + rows
    ) {
      return true;
    }
  }
  return false;
}

/** Check if a block can be placed at (col, row) within `columns` grid */
export function canPlace(
  blocks: DashboardBlock[],
  blockSize: BentoSize,
  col: number,
  row: number,
  columns: number,
  excludeId?: string,
): boolean {
  const { cols, rows } = sizeSpan(effectiveSize(blockSize, columns));
  if (col < 0 || row < 0 || col + cols > columns) return false;

  for (let r = row; r < row + rows; r++) {
    for (let c = col; c < col + cols; c++) {
      if (isCellOccupied(blocks, c, r, columns, excludeId)) return false;
    }
  }
  return true;
}

/** Scan top-left -> bottom-right for the first position a block can fit */
function findFirstPlaceable(
  blocks: DashboardBlock[],
  blockSize: BentoSize,
  columns: number,
  maxRows: number = 20,
  excludeId?: string,
): BlockPosition | null {
  const { cols } = sizeSpan(effectiveSize(blockSize, columns));
  for (let row = 0; row < maxRows; row++) {
    for (let col = 0; col <= columns - cols; col++) {
      if (canPlace(blocks, blockSize, col, row, columns, excludeId)) {
        return { col, row };
      }
    }
  }
  return null;
}

/** Find the nearest placeable position spiraling outward from a preferred position */
function findNearestPlaceable(
  blocks: DashboardBlock[],
  blockSize: BentoSize,
  preferred: BlockPosition,
  columns: number,
  excludeId?: string,
): BlockPosition {
  if (canPlace(blocks, blockSize, preferred.col, preferred.row, columns, excludeId)) {
    return preferred;
  }
  for (let dist = 1; dist < 20; dist++) {
    for (let dr = -dist; dr <= dist; dr++) {
      for (let dc = -dist; dc <= dist; dc++) {
        if (Math.abs(dr) !== dist && Math.abs(dc) !== dist) continue;
        const c = preferred.col + dc;
        const r = preferred.row + dr;
        if (r < 0 || c < 0) continue;
        if (canPlace(blocks, blockSize, c, r, columns, excludeId)) {
          return { col: c, row: r };
        }
      }
    }
  }
  return findFirstPlaceable(blocks, blockSize, columns, 30, excludeId) ?? { col: 0, row: 0 };
}

// ── Masonry compaction ──

/** Compact blocks upward (masonry) — move each block as high as possible */
export function compactBlocks(blocks: DashboardBlock[], columns: number): DashboardBlock[] {
  const sorted = [...blocks].sort(
    (a, b) => a.position.row - b.position.row || a.position.col - b.position.col,
  );

  const result: DashboardBlock[] = [];
  for (const block of sorted) {
    let bestRow = block.position.row;
    for (let tryRow = 0; tryRow <= block.position.row; tryRow++) {
      if (canPlace(result, block.size, block.position.col, tryRow, columns)) {
        bestRow = tryRow;
        break;
      }
    }
    result.push({ ...block, position: { col: block.position.col, row: bestRow } });
  }
  return result;
}

// ── Responsive normalization ──

/**
 * Reflow blocks into a new column count.
 * IMPORTANT: Original block sizes are always preserved.
 * Only positions are recalculated.
 */
export function normalizeToColumns(blocks: DashboardBlock[], columns: number): DashboardBlock[] {
  const sorted = [...blocks].sort(
    (a, b) => a.position.row - b.position.row || a.position.col - b.position.col,
  );

  const result: DashboardBlock[] = [];
  for (const block of sorted) {
    const pos = findFirstPlaceable(result, block.size, columns, 30);
    result.push({ ...block, position: pos ?? { col: 0, row: result.length } });
  }
  return result;
}

// ── Insertion preview (for DnD) ──

/**
 * Simulate moving `blockId` to `targetPos` and push/cascade other blocks.
 * Returns the new block array after the move + compaction.
 */
export function buildInsertionPreview(
  blocks: DashboardBlock[],
  blockId: string,
  targetPos: BlockPosition,
  columns: number,
): DashboardBlock[] {
  const movingBlock = blocks.find((b) => b.id === blockId);
  if (!movingBlock) return blocks;

  const moved: DashboardBlock = { ...movingBlock, position: targetPos };
  const others = blocks.filter((b) => b.id !== blockId);

  const placed: DashboardBlock[] = [moved];
  const sortedOthers = [...others].sort(
    (a, b) => a.position.row - b.position.row || a.position.col - b.position.col,
  );

  for (const block of sortedOthers) {
    if (canPlace(placed, block.size, block.position.col, block.position.row, columns)) {
      placed.push(block);
    } else {
      const pos = findNearestPlaceable(placed, block.size, block.position, columns, block.id);
      placed.push({ ...block, position: pos });
    }
  }

  return compactBlocks(placed, columns);
}

/** Compute grid rows needed for current layout */
export function gridRows(blocks: DashboardBlock[], columns: number): number {
  let max = 0;
  for (const b of blocks) {
    const { rows } = sizeSpan(effectiveSize(b.size, columns));
    max = Math.max(max, b.position.row + rows);
  }
  return max;
}

/** Get the default blocks for a given column count */
export function getDefaultBlocks(columns: number): DashboardBlock[] {
  if (columns === 4) return DEFAULT_DASHBOARD_BLOCKS;
  return normalizeToColumns(DEFAULT_DASHBOARD_BLOCKS, columns);
}

/** Check if a cell is occupied (for rendering empty-cell indicators) */
export function isCellEmpty(
  blocks: DashboardBlock[],
  col: number,
  row: number,
  columns: number,
): boolean {
  return !isCellOccupied(blocks, col, row, columns);
}

/** Resize a block to a new BentoSize, reflow others if needed */
export function resizeBlock(
  blocks: DashboardBlock[],
  blockId: string,
  newSize: BentoSize,
  columns: number,
): DashboardBlock[] {
  const block = blocks.find((b) => b.id === blockId);
  if (!block) return blocks;

  const resized: DashboardBlock = { ...block, size: newSize };

  // Check if the resized block fits at its current position
  const others = blocks.filter((b) => b.id !== blockId);
  if (canPlace(others, newSize, block.position.col, block.position.row, columns)) {
    // Fits in place — just swap and compact
    return compactBlocks([resized, ...others], columns);
  }

  // Doesn't fit — find a new position for it, then cascade others
  const pos = findFirstPlaceable([], newSize, columns, 30);
  if (!pos) return blocks; // can't place at all, bail
  return buildInsertionPreview([resized, ...others], blockId, pos, columns);
}

/** Add a block at a target position (for the picker) */
export function addBlockAt(
  blocks: DashboardBlock[],
  block: DashboardBlock,
  columns: number,
): DashboardBlock[] {
  const all = [...blocks, block];
  return compactBlocks(all, columns);
}
