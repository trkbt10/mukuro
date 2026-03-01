import { useNavigate } from 'react-router-dom';
import { RotateCcw, Bot, Cpu, KeyRound } from 'lucide-react';
import { Badge, Loading, StatCard } from '@/components/ui';
import { PageToolbar } from '@/components/layout/PageToolbar';
import { useAllSettings, useAiProviders } from '@/hooks';
import styles from './Settings.module.css';

const sections = [
  { key: 'retry', label: 'Retry Settings', desc: 'Configure retry behavior for failed API calls', icon: RotateCcw },
  { key: 'agent', label: 'Agent Settings', desc: 'Configure agent loop parameters', icon: Bot },
];

export function Settings() {
  const navigate = useNavigate();
  const { data: settings, isLoading } = useAllSettings();
  const { data: aiProviders } = useAiProviders();

  if (isLoading) {
    return <Loading message="Loading settings..." />;
  }

  return (
    <div className={styles.page}>
      <PageToolbar
        title="Settings"
        subtitle="Configure your mukuro instance. Select a section from the sidebar to edit."
      />

      <div className={styles.statGrid}>
        <StatCard label="Providers" value={aiProviders?.length ?? 0} icon={KeyRound} iconBg="var(--mk-accent-subtle)" iconColor="var(--mk-accent)" />
        <StatCard label="Model" value={settings?.model.model_name ?? '—'} icon={Cpu} iconBg="var(--mk-info-subtle)" iconColor="var(--mk-info)" />
      </div>

      <div className={styles.sectionList}>
        {sections.map((s) => {
          const Icon = s.icon;
          return (
            <div key={s.key} className={styles.sectionRow} onClick={() => navigate(`/settings/${s.key}`)} style={{ cursor: 'pointer' }}>
              <div className={styles.sectionInfo}>
                <Icon style={{ width: 14, height: 14, color: 'var(--mk-text-muted)', flexShrink: 0 }} />
                <div>
                  <span className={styles.sectionName}>{s.label}</span>
                  <p className={styles.sectionDesc}>{s.desc}</p>
                </div>
              </div>
              <Badge variant="default" size="sm">Configurable</Badge>
            </div>
          );
        })}
      </div>

      {aiProviders && aiProviders.length > 0 && (
        <>
          <h2 className={styles.pageTitle} style={{ fontSize: '1rem', marginTop: '1.5rem' }}>AI Providers</h2>
          <div className={styles.sectionList}>
            {aiProviders.map((p) => (
              <div key={p.name} className={styles.sectionRow} onClick={() => navigate(`/settings/ai-providers/${p.name}`)} style={{ cursor: 'pointer' }}>
                <div className={styles.sectionInfo}>
                  <Cpu style={{ width: 14, height: 14, color: 'var(--mk-text-muted)', flexShrink: 0 }} />
                  <div>
                    <span className={styles.sectionName}>{p.name}</span>
                    <p className={styles.sectionDesc}>{p.default_model}</p>
                  </div>
                </div>
                <Badge variant={p.has_api_key ? 'success' : 'default'} size="sm">
                  {p.has_api_key ? 'Key set' : 'No key'}
                </Badge>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
