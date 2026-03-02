import { useParams, Link } from 'react-router-dom';
import { Activity, Puzzle, Server, Code2 } from 'lucide-react';
import {
  Badge,
  Loading,
  Toggle,
  PanelSection,
  PropertyRow,
} from '@/components/ui';
import { PageToolbar } from '@/components/layout/PageToolbar';
import { useTool, useEnableTool, useDisableTool } from '@/hooks';
import { ToolSettingsPanel, getToolPanels } from '@/components/tools';
import type { ToolSettingsSchema } from '@mukuro/client';
import styles from './ToolDetail.module.css';

const sourceIcons: Record<string, typeof Activity> = {
  plugin: Puzzle,
  mcp: Server,
  user_defined: Code2,
};

export function ToolDetail() {
  const { id } = useParams<{ id: string }>();
  const { data: tool, isLoading } = useTool(id ?? '');
  const enableTool = useEnableTool();
  const disableTool = useDisableTool();

  if (isLoading) {
    return <Loading message="Loading tool..." />;
  }

  if (!tool) {
    return (
      <div className={styles.emptyState}>
        <p className={styles.notFoundText}>Tool not found</p>
        <Link to="/tools">Back to tools</Link>
      </div>
    );
  }

  const handleToggle = () => {
    if (tool.enabled) {
      disableTool.mutate(tool.id);
    } else {
      enableTool.mutate(tool.id);
    }
  };

  const SourceIcon = sourceIcons[tool.source] ?? Activity;
  // Use settings schema from API (defined in backend)
  const settingsSchema: ToolSettingsSchema | undefined = tool.settings_schema;
  const customPanels = getToolPanels(tool.name);

  return (
    <div className={styles.page}>
      <PageToolbar
        back="/tools"
        title={tool.name}
        titleBadge={
          <Badge
            variant={tool.source === 'plugin' ? 'default' : tool.source === 'mcp' ? 'warning' : 'success'}
            size="sm"
          >
            {tool.source === 'user_defined' ? 'custom' : tool.source}
          </Badge>
        }
      />

      <div className={styles.grid}>
        <PanelSection title="Details">
          <div className={styles.propList}>
            <PropertyRow label="Status">
              <Badge variant={tool.enabled ? 'success' : 'default'}>
                {tool.enabled ? 'Enabled' : 'Disabled'}
              </Badge>
            </PropertyRow>
            <PropertyRow label="Source">
              <div className={styles.sourceRow}>
                <SourceIcon style={{ width: 14, height: 14 }} />
                <span>{tool.source === 'user_defined' ? 'custom' : tool.source}</span>
                {tool.source_id && (
                  <span className={styles.sourceId}>({tool.source_id})</span>
                )}
              </div>
            </PropertyRow>
            <PropertyRow label="Tool Status">
              <Badge variant={tool.status === 'available' ? 'success' : tool.status === 'disabled' ? 'default' : 'error'}>
                {tool.status}
              </Badge>
            </PropertyRow>
            {tool.status_message && (
              <PropertyRow label="Status Message">
                <span className={styles.statusMessage}>{tool.status_message}</span>
              </PropertyRow>
            )}
            <div className={styles.enableRow}>
              <span className={styles.enableLabel}>Enable Tool</span>
              <Toggle
                checked={tool.enabled}
                onChange={handleToggle}
                disabled={enableTool.isPending || disableTool.isPending}
              />
            </div>
          </div>
        </PanelSection>

        <PanelSection title="Description">
          <p className={styles.descriptionText}>
            {tool.description || 'No description available'}
          </p>
        </PanelSection>

        <PanelSection title="Parameters Schema">
          <div className={styles.schemaBlock}>
            <pre className={styles.schemaCode}>
              {JSON.stringify(tool.parameters, null, 2)}
            </pre>
          </div>
        </PanelSection>
      </div>

      {settingsSchema && (
        <ToolSettingsPanel toolId={tool.id} toolName={tool.name} schema={settingsSchema} />
      )}

      {customPanels.map(({ component: Panel, label }) => (
        <Panel key={label} />
      ))}
    </div>
  );
}
