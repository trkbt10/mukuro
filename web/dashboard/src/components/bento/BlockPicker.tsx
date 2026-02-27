import { useEffect, useRef } from 'react';
import type { DashboardBlockId } from './layout-types';
import { BLOCK_CATALOG, type BlockMeta } from './layout-types';
import styles from './BentoGrid.module.css';

type BlockPickerProps = {
  hiddenBlockIds: DashboardBlockId[];
  onSelect: (blockId: DashboardBlockId) => void;
  onClose: () => void;
};

export function BlockPicker({ hiddenBlockIds, onSelect, onClose }: BlockPickerProps) {
  const ref = useRef<HTMLDivElement>(null);

  // Close on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        onClose();
      }
    };
    document.addEventListener('pointerdown', handler);
    return () => document.removeEventListener('pointerdown', handler);
  }, [onClose]);

  if (hiddenBlockIds.length === 0) {
    return (
      <div ref={ref} className={styles.blockPicker}>
        <div className={styles.blockPickerEmpty}>All cards placed</div>
      </div>
    );
  }

  return (
    <div ref={ref} className={styles.blockPicker}>
      {hiddenBlockIds.map((id) => {
        const meta: BlockMeta = BLOCK_CATALOG[id];
        return (
          <button
            key={id}
            className={styles.blockPickerItem}
            onClick={() => { onSelect(id); onClose(); }}
          >
            <span className={styles.blockPickerIcon}>{meta.icon}</span>
            <span>{meta.label}</span>
          </button>
        );
      })}
    </div>
  );
}
