import type { ReactNode } from 'react';
import { X } from 'lucide-react';
import { useDraggable } from '@dnd-kit/core';
import { CSS } from '@dnd-kit/utilities';
import type { BentoSize } from './grid/fractal';
import { BentoBlock } from './BentoGrid';
import { ResizeHandle } from './ResizeHandle';
import styles from './BentoGrid.module.css';

type DraggableBlockProps = {
  id: string;
  size: BentoSize;
  position: { col: number; row: number };
  columns?: number;
  jiggle?: boolean;
  onResize?: (blockId: string, newSize: BentoSize) => void;
  onRemove?: (blockId: string) => void;
  children: ReactNode;
};

export function DraggableBlock({
  id, size, position, columns, jiggle, onResize, onRemove, children,
}: DraggableBlockProps) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({ id });

  const dragStyle = transform
    ? { transform: CSS.Translate.toString(transform), zIndex: 100 }
    : undefined;

  return (
    <BentoBlock
      ref={setNodeRef}
      size={size}
      position={position}
      columns={columns}
      jiggle={jiggle && !isDragging}
      dragging={isDragging}
      style={{ ...dragStyle, cursor: 'grab', position: 'relative' as const }}
      {...listeners}
      {...attributes}
    >
      {children}
      {/* Transparent overlay prevents click-through to card links */}
      <div
        style={{ position: 'absolute', inset: 0, zIndex: 1 }}
        onClickCapture={(e) => { e.preventDefault(); e.stopPropagation(); }}
      />
      {/* Remove button (top-left) */}
      {onRemove && (
        <button
          className={styles.removeButton}
          onClick={(e) => { e.stopPropagation(); onRemove(id); }}
          onPointerDown={(e) => e.stopPropagation()}
          title="Remove card"
        >
          <X style={{ width: 12, height: 12 }} />
        </button>
      )}
      {/* Resize handle (bottom-right) */}
      {onResize && columns && (
        <ResizeHandle
          blockId={id}
          currentSize={size}
          columns={columns}
          onResize={onResize}
        />
      )}
    </BentoBlock>
  );
}
