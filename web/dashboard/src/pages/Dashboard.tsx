import { Puzzle, MessageSquare, Settings as SettingsIcon, Activity } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Loading, Badge, PanelSection, StatCard, type StatCardProps } from '@/components/ui';
import { usePlugins, useAllSettings } from '@/hooks';
import styles from './Dashboard.module.css';

function LinkedStatCard({ href, ...props }: StatCardProps & { href: string }) {
  return (
    <Link to={href}>
      <StatCard {...props} />
    </Link>
  );
}

export function Dashboard() {
  const { data: plugins, isLoading: pluginsLoading } = usePlugins();
  const { data: settings, isLoading: settingsLoading } = useAllSettings();

  if (pluginsLoading || settingsLoading) {
    return <Loading message="Loading dashboard..." />;
  }

  const enabledPlugins = plugins?.filter((p) => p.enabled).length ?? 0;
  const totalPlugins = plugins?.length ?? 0;
  const providerCount = settings?.providers.length ?? 0;

  return (
    <div className={styles.page}>
      <div>
        <h1 className={styles.pageTitle}>Dashboard</h1>
        <p className={styles.pageDesc}>Overview of your mukuro instance</p>
      </div>

      <div className={styles.statGrid}>
        <LinkedStatCard label="Active Plugins" value={`${enabledPlugins}/${totalPlugins}`} icon={Puzzle} href="/plugins" iconBg="var(--mk-accent)" />
        <LinkedStatCard label="Prompts" value="Configured" icon={MessageSquare} href="/prompts" iconBg="var(--mk-info)" />
        <LinkedStatCard label="Providers" value={providerCount} icon={SettingsIcon} href="/settings" iconBg="#8b5cf6" />
        <LinkedStatCard label="Status" value="Healthy" icon={Activity} href="/settings" iconBg="var(--mk-success)" />
      </div>

      <div className={styles.contentGrid}>
        <PanelSection title="Recent Plugins">
          {plugins && plugins.length > 0 ? (
            <div className={styles.pluginList}>
              {plugins.slice(0, 5).map((plugin) => (
                <Link key={plugin.id} to={`/plugins/${plugin.id}`}>
                  <div className={styles.pluginRow}>
                    <div>
                      <p className={styles.pluginName}>{plugin.name}</p>
                      <p className={styles.pluginVersion}>v{plugin.version}</p>
                    </div>
                    <Badge variant={plugin.enabled ? 'success' : 'default'} size="sm">
                      {plugin.enabled ? 'Active' : 'Inactive'}
                    </Badge>
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <p className={styles.emptyState}>No plugins installed</p>
          )}
        </PanelSection>

        <PanelSection title="Quick Settings">
          <div className={styles.settingsList}>
            <div className={styles.settingsItem}>
              <span className={styles.settingsLabel}>Model</span>
              <span className={styles.settingsValue}>
                {settings?.model.model_name ?? 'Not configured'}
              </span>
            </div>
            <div className={styles.settingsItem}>
              <span className={styles.settingsLabel}>Max Retries</span>
              <span className={styles.settingsValue}>
                {settings?.retry.max_retries ?? 3}
              </span>
            </div>
            <div className={styles.settingsItem}>
              <span className={styles.settingsLabel}>Max Iterations</span>
              <span className={styles.settingsValue}>
                {settings?.agent.max_iterations ?? 10}
              </span>
            </div>
            <Link to="/settings" className={styles.viewAllLink}>
              View all settings
            </Link>
          </div>
        </PanelSection>
      </div>
    </div>
  );
}
