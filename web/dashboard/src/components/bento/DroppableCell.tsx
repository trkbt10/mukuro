import { useState, useCallback } from 'react';
import { Plus } from 'lucide-react';
import { useDroppable } from '@dnd-kit/core';
import type { DashboardBlockId } from './layout-types';
import { BlockPicker } from './BlockPicker';
import styles from './BentoGrid.module.css';

type DroppableCellProps = {
  col: number;
  row: number;
  empty?: boolean;
  hiddenBlockIds?: DashboardBlockId[];
  onAddBlock?: (blockId: DashboardBlockId, col: number, row: number) => void;
};

export function DroppableCell({ col, row, empty, hiddenBlockIds, onAddBlock }: DroppableCellProps) {
  const id = `cell-${col}-${row}`;
  const { setNodeRef, isOver } = useDroppable({ id, data: { col, row } });
  const [pickerOpen, setPickerOpen] = useState(false);

  const showPicker = empty && hiddenBlockIds && hiddenBlockIds.length > 0;

  const handleClick = useCallback(() => {
    if (showPicker) setPickerOpen(true);
  }, [showPicker]);

  const handleSelect = useCallback(
    (blockId: DashboardBlockId) => {
      onAddBlock?.(blockId, col, row);
    },
    [onAddBlock, col, row],
  );

  return (
    <div
      ref={setNodeRef}
      className={styles.droppableCell}
      data-over={isOver ? 'true' : undefined}
      data-empty={empty ? 'true' : undefined}
      style={{
        gridColumnStart: col + 1,
        gridRowStart: row + 1,
        position: 'relative',
      }}
      onClick={handleClick}
    >
      {empty && (
        <div className={styles.emptyCellHint}>
          <Plus style={{ width: 20, height: 20 }} />
        </div>
      )}
      {pickerOpen && (
        <BlockPicker
          hiddenBlockIds={hiddenBlockIds ?? []}
          onSelect={handleSelect}
          onClose={() => setPickerOpen(false)}
        />
      )}
    </div>
  );
}
