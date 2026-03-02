import { Link } from 'react-router-dom';
import { Wrench, Activity, Puzzle, Server } from 'lucide-react';
import { Badge, Loading, StatCard, Toggle } from '@/components/ui';
import { PageToolbar } from '@/components/layout/PageToolbar';
import { useTools, useEnableTool, useDisableTool } from '@/hooks';
import styles from './Tools.module.css';

export function Tools() {
  const { data, isLoading } = useTools();
  const enableTool = useEnableTool();
  const disableTool = useDisableTool();

  if (isLoading) {
    return <Loading message="Loading tools..." />;
  }

  const tools = data?.tools ?? [];
  const stats = data?.stats ?? {
    total: 0,
    enabled: 0,
    plugin: 0,
    user_defined: 0,
    mcp: 0,
  };

  const handleToggle = (id: string, enabled: boolean) => {
    if (enabled) {
      disableTool.mutate(id);
    } else {
      enableTool.mutate(id);
    }
  };

  return (
    <div className={styles.page}>
      <PageToolbar
        title="Tools"
        subtitle="Manage available tools for the agent. Enable or disable tools to control agent capabilities."
      />

      <div className={styles.statGrid}>
        <StatCard label="Total" value={stats.total} icon={Wrench} iconBg="var(--mk-accent-subtle)" iconColor="var(--mk-accent)" />
        <StatCard label="Enabled" value={stats.enabled} icon={Activity} iconBg="var(--mk-success-subtle)" iconColor="var(--mk-success)" />
        <StatCard label="Plugin" value={stats.plugin} icon={Puzzle} iconBg="var(--mk-info-subtle)" iconColor="var(--mk-info)" />
        <StatCard label="MCP" value={stats.mcp} icon={Server} iconBg="var(--mk-warning-subtle)" iconColor="var(--mk-warning)" />
      </div>

      {tools.length > 0 && (
        <div className={styles.toolList}>
          {tools.map((tool) => (
            <div key={tool.id} className={styles.toolRow}>
              <Link to={`/tools/${encodeURIComponent(tool.id)}`} className={styles.toolInfo}>
                <span className={styles.toolName}>{tool.name}</span>
                <span className={styles.toolDesc}>{tool.description}</span>
              </Link>
              <div className={styles.toolMeta}>
                <span className={styles.sourceBadge} data-source={tool.source}>
                  {tool.source === 'user_defined' ? 'custom' : tool.source}
                </span>
                <Badge variant={tool.enabled ? 'success' : 'default'} size="sm">
                  {tool.enabled ? 'Enabled' : 'Disabled'}
                </Badge>
                <Toggle
                  checked={tool.enabled}
                  onChange={() => handleToggle(tool.id, tool.enabled)}
                  disabled={enableTool.isPending || disableTool.isPending}
                />
              </div>
            </div>
          ))}
        </div>
      )}

      {tools.length === 0 && (
        <div className={styles.emptyState}>
          <Server style={{ width: 48, height: 48, color: 'var(--mk-text-muted)' }} />
          <p>No tools available</p>
        </div>
      )}
    </div>
  );
}
