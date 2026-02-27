import React from 'react';
import type { HTMLAttributes } from 'react';
import { CELL, GAP, type BentoSize } from './grid/fractal';
import styles from './BentoGrid.module.css';

// ============================================================
// BentoGrid — Layout Container
// ============================================================

export type BentoGridProps = HTMLAttributes<HTMLDivElement> & {
  columns?: number;
  squareCells?: boolean;
};

export const BentoGrid = React.forwardRef<HTMLDivElement, BentoGridProps>(
  ({ className, columns = 4, squareCells = false, style, children, ...props }, ref) => {
    const innerRef = React.useRef<HTMLDivElement | null>(null);

    const setRefs = React.useCallback(
      (node: HTMLDivElement | null) => {
        innerRef.current = node;
        if (typeof ref === 'function') ref(node);
        else if (ref) ref.current = node;
      },
      [ref],
    );

    React.useLayoutEffect(() => {
      if (!squareCells) return;
      const node = innerRef.current;
      if (!node) return;

      const update = () => {
        const width = node.clientWidth;
        const cellSize = (width * CELL) / (columns * CELL + (columns - 1) * GAP);
        const gap = (cellSize * GAP) / CELL;
        node.style.setProperty('--bento-cell-size', `${Math.max(cellSize, 0)}px`);
        node.style.setProperty('--bento-gap', `${Math.max(gap, 0)}px`);
      };

      update();
      const observer = new ResizeObserver(() => update());
      observer.observe(node);
      return () => observer.disconnect();
    }, [columns, squareCells]);

    return (
      <div
        ref={setRefs}
        className={`${styles.grid}${className ? ` ${className}` : ''}`}
        data-square-cells={squareCells ? 'true' : undefined}
        style={{ gridTemplateColumns: `repeat(${columns}, 1fr)`, ...style }}
        {...props}
      >
        {children}
      </div>
    );
  },
);
BentoGrid.displayName = 'BentoGrid';

// ============================================================
// BentoBlock — Grid positioning wrapper (no visual styling)
// ============================================================

export type BentoBlockProps = HTMLAttributes<HTMLDivElement> & {
  size: BentoSize;
  entering?: boolean;
  position?: { col: number; row: number };
  /** Grid column count — used to clamp span so blocks don't overflow the grid */
  columns?: number;
  jiggle?: boolean;
  dragging?: boolean;
};

export const BentoBlock = React.forwardRef<HTMLDivElement, BentoBlockProps>(
  ({ className, size, entering, position, columns, jiggle, dragging, style, children, ...props }, ref) => {
    const [rawCols, rawRows] = size.split('x').map(Number);
    const cols = columns ? Math.min(rawCols!, columns) : rawCols;
    const rows = rawRows;
    const positionStyle: React.CSSProperties | undefined = position
      ? {
          gridColumnStart: position.col + 1,
          gridColumnEnd: `span ${cols}`,
          gridRowStart: position.row + 1,
          gridRowEnd: `span ${rows}`,
        }
      : undefined;

    return (
      <div
        ref={ref}
        className={`${styles.block}${className ? ` ${className}` : ''}`}
        data-size={size}
        data-entering={entering ? 'true' : undefined}
        data-jiggle={jiggle ? 'true' : undefined}
        data-dragging={dragging ? 'true' : undefined}
        style={{ ...positionStyle, ...style }}
        {...props}
      >
        {children}
      </div>
    );
  },
);
BentoBlock.displayName = 'BentoBlock';
