import { FileText, CheckCircle, Circle } from 'lucide-react';
import { Badge, Loading, StatCard } from '@/components/ui';
import { useContextDataFiles } from '@/hooks';
import { fileDescriptions } from '@/lib/contextFiles';
import styles from './Context.module.css';

export function Context() {
  const { data: contextFiles, isLoading } = useContextDataFiles();

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
        <StatCard label="Total Files" value={total} icon={FileText} iconBg="var(--mk-accent-subtle)" iconColor="var(--mk-accent)" />
        <StatCard label="Active" value={active} icon={CheckCircle} iconBg="var(--mk-success-subtle)" iconColor="var(--mk-success)" />
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
