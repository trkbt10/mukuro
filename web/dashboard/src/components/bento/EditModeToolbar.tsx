import type { FC } from 'react';
import { Pencil, Check, RotateCcw } from 'lucide-react';
import styles from './EditModeToolbar.module.css';

type EditModeToolbarProps = {
  isEditing: boolean;
  onEdit: () => void;
  onDone: () => void;
  onReset: () => void;
};

export const EditModeToolbar: FC<EditModeToolbarProps> = ({ isEditing, onEdit, onDone, onReset }) => {
  if (!isEditing) {
    return (
      <div className={styles.toolbar}>
        <button className={styles.editButton} onClick={onEdit} title="Edit Layout">
          <Pencil style={{ width: 14, height: 14 }} />
          Edit
        </button>
      </div>
    );
  }

  return (
    <div className={styles.toolbar}>
      <button className={styles.resetButton} onClick={onReset} title="Reset Layout">
        <RotateCcw style={{ width: 14, height: 14 }} />
        Reset
      </button>
      <button className={styles.doneButton} onClick={onDone} title="Done Editing">
        <Check style={{ width: 14, height: 14 }} />
        Done
      </button>
    </div>
  );
};
