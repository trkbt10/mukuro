import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { Save, Trash2 } from 'lucide-react';
import { Button, Textarea, Badge, Loading, PanelSection } from '@/components/ui';
import { useContextFile, useUpdateContextFile, useDeleteContextFile } from '@/hooks';
import styles from './ContextDetail.module.css';

const fileDescriptions: Record<string, string> = {
  soul: 'AI personality and core values',
  identity: 'AI identity and name',
  bootstrap: 'Base system instructions',
  agents: 'Workspace handbook and guidelines',
  tools: 'Local tools and environment configuration',
  user: 'User preferences and context',
};

const filePlaceholders: Record<string, string> = {
  soul: 'Define the AI personality, tone, and core values...',
  identity: 'Define the AI identity and name...',
  bootstrap: 'Base system instructions sent at the start of each session...',
  agents: 'Workspace handbook and guidelines for agent behavior...',
  tools: 'Local tools and environment configuration...',
  user: 'User preferences and personal context...',
};

export function ContextDetail() {
  const { name } = useParams<{ name: string }>();
  const { data: file, isLoading } = useContextFile(name ?? '');
  const updateContextFile = useUpdateContextFile();
  const deleteContextFile = useDeleteContextFile();

  const [content, setContent] = useState('');
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    if (file) {
      setContent(file.content);
      setDirty(false);
    }
  }, [file]);

  const handleSave = () => {
    if (!name) return;
    updateContextFile.mutate(
      { name, content },
      { onSuccess: () => setDirty(false) }
    );
  };

  const handleDelete = () => {
    if (!name) return;
    deleteContextFile.mutate(name, {
      onSuccess: () => {
        setContent('');
        setDirty(false);
      },
    });
  };

  if (isLoading) {
    return <Loading message="Loading context file..." />;
  }

  if (!file) {
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
            <h1 className={styles.pageTitle}>{file.filename}</h1>
            <Badge variant={file.exists ? 'success' : 'default'} size="sm">
              {file.exists ? 'Active' : 'Empty'}
            </Badge>
          </div>
          <p className={styles.pageDesc}>{fileDescriptions[file.name] ?? file.description}</p>
        </div>
        <div className={styles.actions}>
          {file.exists && (
            <Button
              variant="ghost"
              size="sm"
              onClick={handleDelete}
              loading={deleteContextFile.isPending}
              leftIcon={<Trash2 style={{ width: 14, height: 14, color: 'var(--mk-error)' }} />}
            >
              Clear
            </Button>
          )}
          <Button
            size="sm"
            onClick={handleSave}
            loading={updateContextFile.isPending}
            disabled={!dirty}
            leftIcon={<Save style={{ width: 14, height: 14 }} />}
          >
            Save
          </Button>
        </div>
      </div>

      <PanelSection title="Content">
        <Textarea
          value={content}
          onChange={(e) => { setContent(e.target.value); setDirty(true); }}
          rows={20}
          placeholder={filePlaceholders[file.name] ?? 'Enter content...'}
        />
      </PanelSection>
    </div>
  );
}
