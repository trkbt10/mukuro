import { useState } from 'react';
import { Puzzle, PackageCheck, Upload, Activity } from 'lucide-react';
import { Button, Badge, Loading, Modal, toast, StatCard } from '@/components/ui';
import { usePlugins, useUploadPlugin } from '@/hooks';
import styles from './Plugins.module.css';

export function Plugins() {
  const { data: plugins, isLoading } = usePlugins();
  const uploadPlugin = useUploadPlugin();

  const [uploadModalOpen, setUploadModalOpen] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);

  const handleUpload = () => {
    if (!selectedFile) {
      toast.error('Please select a file');
      return;
    }
    uploadPlugin.mutate(
      { file: selectedFile },
      {
        onSuccess: () => {
          setUploadModalOpen(false);
          setSelectedFile(null);
        },
      }
    );
  };

  if (isLoading) {
    return <Loading message="Loading plugins..." />;
  }

  const total = plugins?.length ?? 0;
  const active = plugins?.filter((p) => p.enabled).length ?? 0;
  const builtin = plugins?.filter((p) => p.is_builtin).length ?? 0;

  return (
    <div className={styles.page}>
      <div className={styles.header}>
        <div>
          <h1 className={styles.pageTitle}>Plugins</h1>
          <p className={styles.pageDesc}>Manage installed plugins. Select one from the sidebar to view details.</p>
        </div>
        <Button size="sm" onClick={() => setUploadModalOpen(true)} leftIcon={<Upload style={{ width: 14, height: 14 }} />}>
          Upload Plugin
        </Button>
      </div>

      <div className={styles.statGrid}>
        <StatCard label="Total" value={total} icon={Puzzle} iconBg="var(--mk-accent-subtle)" iconColor="var(--mk-accent)" />
        <StatCard label="Active" value={active} icon={Activity} iconBg="var(--mk-success-subtle)" iconColor="var(--mk-success)" />
        <StatCard label="Built-in" value={builtin} icon={PackageCheck} iconBg="var(--mk-info-subtle)" iconColor="var(--mk-info)" />
      </div>

      {total > 0 && (
        <div className={styles.pluginList}>
          {plugins?.map((p) => (
            <div key={p.id} className={styles.pluginRow}>
              <div className={styles.pluginInfo}>
                <span className={styles.pluginName}>{p.name}</span>
                <span className={styles.pluginVersion}>v{p.version}</span>
              </div>
              <Badge variant={p.enabled ? 'success' : 'default'} size="sm">
                {p.enabled ? 'Active' : 'Inactive'}
              </Badge>
            </div>
          ))}
        </div>
      )}

      <Modal
        open={uploadModalOpen}
        onClose={() => setUploadModalOpen(false)}
        title="Upload Plugin"
        description="Upload a plugin ZIP package"
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setUploadModalOpen(false)}>Cancel</Button>
            <Button onClick={handleUpload} loading={uploadPlugin.isPending} disabled={!selectedFile}>Upload</Button>
          </>
        }
      >
        <div className={styles.uploadArea}>
          <input
            type="file"
            accept=".zip"
            onChange={(e) => setSelectedFile(e.target.files?.[0] ?? null)}
            className={styles.fileInput}
          />
          {selectedFile && <p className={styles.selectedFile}>Selected: {selectedFile.name}</p>}
        </div>
      </Modal>
    </div>
  );
}
