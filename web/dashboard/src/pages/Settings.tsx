import { Settings as SettingsIcon, RotateCcw, Bot, Cpu, Brain } from 'lucide-react';
import { Badge, Loading, StatCard } from '@/components/ui';
import { useAllSettings } from '@/hooks';
import styles from './Settings.module.css';

const sections = [
  { key: 'retry', label: 'Retry Settings', desc: 'Configure retry behavior for failed API calls', icon: RotateCcw },
  { key: 'agent', label: 'Agent Settings', desc: 'Configure agent loop parameters', icon: Bot },
  { key: 'model', label: 'Model Settings', desc: 'Configure the AI model parameters', icon: Cpu },
  { key: 'thinking', label: 'Thinking Settings', desc: 'Configure extended thinking behavior', icon: Brain },
];

export function Settings() {
  const { data: settings, isLoading } = useAllSettings();

  if (isLoading) {
    return <Loading message="Loading settings..." />;
  }

  return (
    <div className={styles.page}>
      <div>
        <h1 className={styles.pageTitle}>Settings</h1>
        <p className={styles.pageDesc}>Configure your mukuro instance. Select a section from the sidebar to edit.</p>
      </div>

      <div className={styles.statGrid}>
        <StatCard label="Sections" value={sections.length} icon={SettingsIcon} iconBg="var(--mk-accent-subtle)" iconColor="var(--mk-accent)" />
        <StatCard label="Model" value={settings?.model.model_name ?? '—'} icon={Cpu} iconBg="var(--mk-info-subtle)" iconColor="var(--mk-info)" />
      </div>

      <div className={styles.sectionList}>
        {sections.map((s) => {
          const Icon = s.icon;
          return (
            <div key={s.key} className={styles.sectionRow}>
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
    </div>
  );
}
