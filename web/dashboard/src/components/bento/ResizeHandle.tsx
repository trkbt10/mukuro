import { useRef, useCallback, useEffect } from 'react';
import type { BentoSize } from './grid/fractal';
import { sizeSpan } from './layout-types';
import styles from './BentoGrid.module.css';

type ResizeHandleProps = {
  blockId: string;
  currentSize: BentoSize;
  columns: number;
  onResize: (blockId: string, newSize: BentoSize) => void;
};

/** Construct BentoSize from cols/rows, clamped to valid range */
function toBentoSize(cols: number, rows: number): BentoSize | null {
  const c = Math.max(1, Math.min(cols, 4));
  const r = Math.max(1, Math.min(rows, 2));
  const s = `${c}x${r}` as BentoSize;
  // Only allow sizes that exist in our system
  const valid: BentoSize[] = ['1x1', '2x1', '1x2', '2x2'];
  return valid.includes(s) ? s : null;
}

export function ResizeHandle({ blockId, currentSize, columns, onResize }: ResizeHandleProps) {
  const startRef = useRef<{
    x: number; y: number;
    cols: number; rows: number;
    cellSize: number; gap: number;
  } | null>(null);
  const lastSizeRef = useRef<BentoSize>(currentSize);

  // Sync lastSizeRef with prop
  useEffect(() => { lastSizeRef.current = currentSize; }, [currentSize]);

  const onPointerMove = useCallback((e: PointerEvent) => {
    const s = startRef.current;
    if (!s) return;

    const dx = e.clientX - s.x;
    const dy = e.clientY - s.y;
    const step = s.cellSize + s.gap;
    const deltaCols = Math.round(dx / step);
    const deltaRows = Math.round(dy / step);

    const newCols = Math.max(1, Math.min(s.cols + deltaCols, columns));
    const newRows = Math.max(1, s.rows + deltaRows);
    const newSize = toBentoSize(newCols, newRows);

    if (newSize && newSize !== lastSizeRef.current) {
      lastSizeRef.current = newSize;
      onResize(blockId, newSize);
    }
  }, [blockId, columns, onResize]);

  const onPointerUp = useCallback(() => {
    startRef.current = null;
    document.removeEventListener('pointermove', onPointerMove);
    document.removeEventListener('pointerup', onPointerUp);
  }, [onPointerMove]);

  const onPointerDown = useCallback((e: React.PointerEvent) => {
    e.stopPropagation(); // prevent dnd-kit drag
    e.preventDefault();

    // Read cell size from closest grid element
    const grid = (e.currentTarget as HTMLElement).closest('[data-square-cells]') as HTMLElement | null;
    let cellSize = 140;
    let gap = 12;
    if (grid) {
      const cs = getComputedStyle(grid);
      cellSize = parseFloat(cs.getPropertyValue('--bento-cell-size')) || 140;
      gap = parseFloat(cs.getPropertyValue('--bento-gap')) || 12;
    }

    const { cols, rows } = sizeSpan(currentSize);
    startRef.current = { x: e.clientX, y: e.clientY, cols, rows, cellSize, gap };

    document.addEventListener('pointermove', onPointerMove);
    document.addEventListener('pointerup', onPointerUp);
  }, [currentSize, onPointerMove, onPointerUp]);

  return (
    <div
      className={styles.resizeHandle}
      onPointerDown={onPointerDown}
      title="Drag to resize"
    >
      <svg width={32} height={32} viewBox="0 0 32 32" fill="none">
        <path
          d="M30 2 L30 6 Q30 30 6 30 L2 30"
          stroke="currentColor"
          strokeWidth={1.5}
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </div>
  );
}
