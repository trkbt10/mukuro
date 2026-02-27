import { FileText, CheckCircle, Circle } from 'lucide-react';
import { Badge, Loading } from '@/components/ui';
import { useContextFiles } from '@/hooks';
import styles from './Context.module.css';

const fileDescriptions: Record<string, string> = {
  soul: 'AI personality and core values',
  identity: 'AI identity and name',
  bootstrap: 'Base system instructions',
  agents: 'Workspace handbook and guidelines',
  tools: 'Local tools and environment configuration',
  user: 'User preferences and context',
};

export function Context() {
  const { data: contextFiles, isLoading } = useContextFiles();

  if (isLoading) {
    return <Loading message="Loading context files..." />;
  }

  const total = contextFiles?.length ?? 0;
  const active = contextFiles?.filter((f) => f.exists).length ?? 0;

  return (
    <div className={styles.page}>
      <div>
        <h1 className={styles.pageTitle}>Context</h1>
        <p className={styles.pageDesc}>
          Manage workspace context files that shape AI behavior. Select a file from the sidebar to edit.
        </p>
      </div>

      <div className={styles.statGrid}>
        <div className={styles.statCard}>
          <div className={styles.statIcon} style={{ background: 'var(--mk-accent-subtle)' }}>
            <FileText style={{ width: 20, height: 20, color: 'var(--mk-accent)' }} />
          </div>
          <div>
            <p className={styles.statLabel}>Total Files</p>
            <p className={styles.statValue}>{total}</p>
          </div>
        </div>
        <div className={styles.statCard}>
          <div className={styles.statIcon} style={{ background: 'var(--mk-success-subtle)' }}>
            <CheckCircle style={{ width: 20, height: 20, color: 'var(--mk-success)' }} />
          </div>
          <div>
            <p className={styles.statLabel}>Active</p>
            <p className={styles.statValue}>{active}</p>
          </div>
        </div>
      </div>

      {contextFiles && contextFiles.length > 0 && (
        <div className={styles.fileList}>
          {contextFiles.map((f) => (
            <div key={f.name} className={styles.fileRow}>
              <div className={styles.fileInfo}>
                {f.exists
                  ? <CheckCircle style={{ width: 14, height: 14, color: 'var(--mk-success)', flexShrink: 0 }} />
                  : <Circle style={{ width: 14, height: 14, color: 'var(--mk-text-muted)', flexShrink: 0 }} />
                }
                <div>
                  <span className={styles.fileName}>{f.filename}</span>
                  <p className={styles.fileDesc}>{fileDescriptions[f.name] ?? f.description}</p>
                </div>
              </div>
              <Badge variant={f.exists ? 'success' : 'default'} size="sm">
                {f.exists ? 'Active' : 'Empty'}
              </Badge>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
