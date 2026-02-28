import { useState } from 'react';
import { Plus, Eraser, Pencil, Trash2 } from 'lucide-react';
import {
  Button,
  Modal,
  Input,
  PanelSection,
  DeleteConfirmModal,
} from '@/components/ui';
import {
  useMemoryEntries,
  useSetMemoryEntry,
  useDeleteMemoryEntry,
  useClearMemory,
} from '@/hooks';
import styles from './PluginDetail.module.css';

export function MemoryPanel() {
  const { data: memoryData, isLoading } = useMemoryEntries();
  const setEntry = useSetMemoryEntry();
  const deleteEntry = useDeleteMemoryEntry();
  const clearAll = useClearMemory();

  const [entryModalOpen, setEntryModalOpen] = useState(false);
  const [clearModalOpen, setClearModalOpen] = useState(false);
  const [editKey, setEditKey] = useState('');
  const [editValue, setEditValue] = useState('');
  const [isEditing, setIsEditing] = useState(false);

  const entries = memoryData?.entries ?? [];

  const openAddModal = () => {
    setEditKey('');
    setEditValue('');
    setIsEditing(false);
    setEntryModalOpen(true);
  };

  const openEditModal = (key: string, value: unknown) => {
    setEditKey(key);
    setEditValue(typeof value === 'string' ? value : JSON.stringify(value, null, 2));
    setIsEditing(true);
    setEntryModalOpen(true);
  };

  const handleSaveEntry = () => {
    if (!editKey.trim()) return;
    let parsedValue: unknown;
    try {
      parsedValue = JSON.parse(editValue);
    } catch {
      parsedValue = editValue;
    }
    setEntry.mutate(
      { key: editKey.trim(), value: parsedValue },
      { onSuccess: () => setEntryModalOpen(false) }
    );
  };

  const formatValue = (value: unknown): string => {
    if (typeof value === 'string') return value;
    return JSON.stringify(value);
  };

  const truncate = (s: string, max: number) =>
    s.length > max ? s.slice(0, max) + '...' : s;

  return (
    <>
      <PanelSection
        title={`Memory Store (${entries.length})`}
        action={
          <div className={styles.memoryToolbar}>
            <Button
              variant="secondary"
              size="sm"
              onClick={openAddModal}
              leftIcon={<Plus style={{ width: 14, height: 14 }} />}
            >
              Add
            </Button>
            {entries.length > 0 && (
              <Button
                variant="danger"
                size="sm"
                onClick={() => setClearModalOpen(true)}
                leftIcon={<Eraser style={{ width: 14, height: 14 }} />}
              >
                Clear All
              </Button>
            )}
          </div>
        }
      >
        {isLoading ? (
          <p className={styles.descriptionText}>Loading entries...</p>
        ) : entries.length === 0 ? (
          <p className={styles.descriptionText}>No entries stored. Use the agent or click Add to create one.</p>
        ) : (
          <div className={styles.memoryTable}>
            <div className={styles.memoryHeader}>
              <span className={styles.memoryColKey}>Key</span>
              <span className={styles.memoryColValue}>Value</span>
              <span className={styles.memoryColActions} />
            </div>
            {entries.map((entry) => (
              <div key={entry.key} className={styles.memoryRow}>
                <span className={styles.memoryKey}>{entry.key}</span>
                <span className={styles.memoryValue} title={formatValue(entry.value)}>
                  {truncate(formatValue(entry.value), 80)}
                </span>
                <span className={styles.memoryActions}>
                  <button
                    className={styles.memoryActionBtn}
                    onClick={() => openEditModal(entry.key, entry.value)}
                    title="Edit"
                  >
                    <Pencil style={{ width: 13, height: 13 }} />
                  </button>
                  <button
                    className={styles.memoryActionBtnDanger}
                    onClick={() => deleteEntry.mutate(entry.key)}
                    title="Delete"
                  >
                    <Trash2 style={{ width: 13, height: 13 }} />
                  </button>
                </span>
              </div>
            ))}
          </div>
        )}
      </PanelSection>

      <Modal
        open={entryModalOpen}
        onClose={() => setEntryModalOpen(false)}
        title={isEditing ? 'Edit Entry' : 'Add Entry'}
        size="md"
        footer={
          <>
            <Button variant="secondary" onClick={() => setEntryModalOpen(false)}>Cancel</Button>
            <Button onClick={handleSaveEntry} loading={setEntry.isPending} disabled={!editKey.trim()}>
              {isEditing ? 'Update' : 'Add'}
            </Button>
          </>
        }
      >
        <div className={styles.settingsFields}>
          <Input
            label="Key"
            value={editKey}
            onChange={setEditKey}
            disabled={isEditing}
            placeholder="e.g. user_preferences"
          />
          <div className={styles.textareaField}>
            <label className={styles.textareaLabel}>Value (JSON or plain text)</label>
            <textarea
              className={styles.textarea}
              value={editValue}
              onChange={(e) => setEditValue(e.target.value)}
              rows={6}
              placeholder='e.g. "hello" or {"key": "value"}'
            />
          </div>
        </div>
      </Modal>

      <DeleteConfirmModal
        open={clearModalOpen}
        onClose={() => setClearModalOpen(false)}
        title="Clear Memory"
        description="This will remove all entries from the memory store."
        onConfirm={() => clearAll.mutate(undefined, { onSuccess: () => setClearModalOpen(false) })}
        isPending={clearAll.isPending}
      >
        <p className={styles.modalText}>
          <strong>{entries.length}</strong> entries will be permanently removed.
        </p>
      </DeleteConfirmModal>
    </>
  );
}
