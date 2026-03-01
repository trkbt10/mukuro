import { useParams } from 'react-router-dom';
import { Save, Trash2, RotateCcw } from 'lucide-react';
import { Button, Textarea, Badge, Loading, PanelSection } from '@/components/ui';
import { useContextEditor } from '@/hooks/useContextEditor';
import { fileDescriptions, filePlaceholders } from '@/lib/contextFiles';
import styles from './ContextDetail.module.css';

export function ContextDetail() {
  const { name } = useParams<{ name: string }>();
  const editor = useContextEditor(name ?? '');

  if (editor.isLoading) {
    return <Loading message="Loading context file..." />;
  }

  if (!editor.file) {
    return (
      <div className={styles.emptyState}>
        <p>Context file not found</p>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      <div className={styles.header}>
        <div>
          <div className={styles.titleGroup}>
            <h1 className={styles.pageTitle}>{editor.file.filename}</h1>
            <Badge variant={editor.file.exists ? 'success' : 'default'} size="sm">
              {editor.file.exists ? 'Active' : 'Empty'}
            </Badge>
          </div>
          <p className={styles.pageDesc}>
            {fileDescriptions[editor.file.name] ?? editor.file.description}
          </p>
        </div>
        <div className={styles.actions}>
          {editor.template && (
            <Button
              variant="ghost"
              size="sm"
              onClick={editor.resetToTemplate}
              leftIcon={<RotateCcw style={{ width: 14, height: 14 }} />}
            >
              Reset to Template
            </Button>
          )}
          {editor.file.exists && (
            <Button
              variant="ghost"
              size="sm"
              onClick={editor.clear}
              loading={editor.isClearing}
              leftIcon={<Trash2 style={{ width: 14, height: 14, color: 'var(--mk-error)' }} />}
            >
              Clear
            </Button>
          )}
          <Button
            size="sm"
            onClick={editor.save}
            loading={editor.isSaving}
            disabled={!editor.isDirty}
            leftIcon={<Save style={{ width: 14, height: 14 }} />}
          >
            Save
          </Button>
        </div>
      </div>

      <PanelSection title="Content">
        <Textarea
          value={editor.content}
          onChange={(e) => editor.setContent(e.target.value)}
          rows={20}
          placeholder={filePlaceholders[editor.file.name] ?? 'Enter content...'}
        />
      </PanelSection>
    </div>
  );
}
