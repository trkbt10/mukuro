import { useState, useMemo, useCallback } from 'react';
import { PointerSensor, TouchSensor, useSensor, useSensors, type DragStartEvent, type DragOverEvent, type DragEndEvent } from '@dnd-kit/core';
import type { DashboardBlock, BlockPosition } from '@/components/bento/layout-types';
import { buildInsertionPreview } from '@/components/bento/layout-engine';

/** Parse "cell-{col}-{row}" → BlockPosition */
function parseCellId(id: string): BlockPosition | null {
  const m = id.match(/^cell-(\d+)-(\d+)$/);
  if (!m) return null;
  return { col: Number(m[1]), row: Number(m[2]) };
}

export function useEditDragAndDrop(
  blocks: DashboardBlock[],
  columns: number,
  onMove: (blockId: string, target: BlockPosition) => void,
) {
  const [activeDragId, setActiveDragId] = useState<string | null>(null);
  const [overCellId, setOverCellId] = useState<string | null>(null);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 200, tolerance: 5 } }),
  );

  const insertionPreviewBlocks = useMemo(() => {
    if (!activeDragId || !overCellId) return null;
    const pos = parseCellId(overCellId);
    if (!pos) return null;
    return buildInsertionPreview(blocks, activeDragId, pos, columns);
  }, [activeDragId, overCellId, blocks, columns]);

  const handleDragStart = useCallback((event: DragStartEvent) => {
    setActiveDragId(String(event.active.id));
  }, []);

  const handleDragOver = useCallback((event: DragOverEvent) => {
    const overId = event.over?.id;
    setOverCellId(overId != null ? String(overId) : null);
  }, []);

  const handleDragEnd = useCallback(
    (event: DragEndEvent) => {
      const overId = event.over?.id;
      if (activeDragId && overId) {
        const pos = parseCellId(String(overId));
        if (pos) {
          onMove(activeDragId, pos);
        }
      }
      setActiveDragId(null);
      setOverCellId(null);
    },
    [activeDragId, onMove],
  );

  const handleDragCancel = useCallback(() => {
    setActiveDragId(null);
    setOverCellId(null);
  }, []);

  return {
    sensors,
    activeDragId,
    overCellId,
    insertionPreviewBlocks,
    handleDragStart,
    handleDragOver,
    handleDragEnd,
    handleDragCancel,
  };
}
