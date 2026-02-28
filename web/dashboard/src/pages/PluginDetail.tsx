import { useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, RefreshCw, Trash2, Settings } from 'lucide-react';
import {
  Button,
  Badge,
  Toggle,
  Loading,
  Modal,
  Input,
  PanelSection,
  PropertyRow,
  DeleteConfirmModal,
} from '@/components/ui';
import {
  usePlugin,
  usePluginSettings,
  useEnablePlugin,
  useDisablePlugin,
  useReloadPlugin,
  useDeletePlugin,
  useUpdatePluginSettings,
} from '@/hooks';
import { formatDate } from '@/lib/utils';
import { getPluginPanels } from './pluginPanels';
import styles from './PluginDetail.module.css';

export function PluginDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const { data: plugin, isLoading } = usePlugin(id ?? '');
  const { data: settings } = usePluginSettings(id ?? '');
  const enablePlugin = useEnablePlugin();
  const disablePlugin = useDisablePlugin();
  const reloadPlugin = useReloadPlugin();
  const deletePlugin = useDeletePlugin();
  const updateSettings = useUpdatePluginSettings();

  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [settingsModalOpen, setSettingsModalOpen] = useState(false);
  const [editedSettings, setEditedSettings] = useState<Record<string, string>>({});

  if (isLoading) {
    return <Loading message="Loading plugin..." />;
  }

  if (!plugin) {
    return (
      <div className={styles.emptyState}>
        <p className={styles.notFoundText}>Plugin not found</p>
        <Link to="/plugins">Back to plugins</Link>
      </div>
    );
  }

  const handleToggle = () => {
    if (plugin.enabled) {
      disablePlugin.mutate(plugin.id);
    } else {
      enablePlugin.mutate(plugin.id);
    }
  };

  const handleDelete = () => {
    deletePlugin.mutate(plugin.id, {
      onSuccess: () => navigate('/plugins'),
    });
  };

  const handleSaveSettings = () => {
    const settingsToSave: Record<string, unknown> = {};
    Object.entries(editedSettings).forEach(([key, value]) => {
      try {
        settingsToSave[key] = JSON.parse(value);
      } catch {
        settingsToSave[key] = value;
      }
    });
    updateSettings.mutate(
      { id: plugin.id, settings: settingsToSave },
      { onSuccess: () => setSettingsModalOpen(false) }
    );
  };

  const openSettingsModal = () => {
    if (settings?.settings) {
      const stringified: Record<string, string> = {};
      Object.entries(settings.settings).forEach(([key, value]) => {
        stringified[key] = JSON.stringify(value);
      });
      setEditedSettings(stringified);
    }
    setSettingsModalOpen(true);
  };

  // Schema-based panels: render any panels registered for this plugin
  const panels = getPluginPanels(plugin.id);

  return (
    <div className={styles.page}>
      <Link to="/plugins" className={styles.backLink}>
        <ArrowLeft style={{ width: 14, height: 14 }} />
        Back
      </Link>

      <div className={styles.titleRow}>
        <div>
          <div className={styles.titleGroup}>
            <h1 className={styles.pageTitle}>{plugin.name}</h1>
            {plugin.is_builtin && <Badge variant="default" size="sm">Builtin</Badge>}
          </div>
          <p className={styles.pluginId}>{plugin.id}</p>
        </div>
        <div className={styles.actions}>
          {!plugin.is_builtin && (
            <Button variant="secondary" size="sm" onClick={() => reloadPlugin.mutate(plugin.id)} loading={reloadPlugin.isPending} leftIcon={<RefreshCw style={{ width: 14, height: 14 }} />}>
              Reload
            </Button>
          )}
          <Button variant="secondary" size="sm" onClick={openSettingsModal} leftIcon={<Settings style={{ width: 14, height: 14 }} />}>
            Settings
          </Button>
          {!plugin.is_builtin && (
            <Button variant="danger" size="sm" onClick={() => setDeleteModalOpen(true)} leftIcon={<Trash2 style={{ width: 14, height: 14 }} />}>
              Delete
            </Button>
          )}
        </div>
      </div>

      <div className={styles.grid}>
        <PanelSection title="Details">
          <div className={styles.propList}>
            <PropertyRow label="Status">
              <Badge variant={plugin.enabled ? 'success' : 'default'}>
                {plugin.enabled ? 'Active' : 'Inactive'}
              </Badge>
            </PropertyRow>
            <PropertyRow label="Version">{plugin.version}</PropertyRow>
            {plugin.author && <PropertyRow label="Author">{plugin.author}</PropertyRow>}
            {plugin.is_builtin && <PropertyRow label="Type">Built-in Tool</PropertyRow>}
            {!plugin.is_builtin && (
              <>
                <PropertyRow label="Loaded At">{formatDate(plugin.loaded_at)}</PropertyRow>
                <PropertyRow label="Modified At">{formatDate(plugin.modified_at)}</PropertyRow>
              </>
            )}
            <div className={styles.enableRow}>
              <span className={styles.enableLabel}>Enable Plugin</span>
              <Toggle
                checked={plugin.enabled}
                onChange={handleToggle}
                disabled={enablePlugin.isPending || disablePlugin.isPending}
              />
            </div>
          </div>
        </PanelSection>

        <PanelSection title="Description">
          <p className={styles.descriptionText}>
            {plugin.description || 'No description available'}
          </p>
        </PanelSection>

        <PanelSection title="Permissions">
          {plugin.permissions.length > 0 ? (
            <div className={styles.permList}>
              {plugin.permissions.map((perm) => (
                <Badge key={perm} variant="default">{perm}</Badge>
              ))}
            </div>
          ) : (
            <p className={styles.descriptionText}>No special permissions</p>
          )}
        </PanelSection>
      </div>

      {panels.map(({ component: Panel, label }) => (
        <Panel key={label} />
      ))}

      <DeleteConfirmModal
        open={deleteModalOpen}
        onClose={() => setDeleteModalOpen(false)}
        title="Delete Plugin"
        description="Are you sure you want to delete this plugin? This action cannot be undone."
        onConfirm={handleDelete}
        isPending={deletePlugin.isPending}
      >
        <p className={styles.modalText}>
          Plugin <strong>{plugin.name}</strong> will be permanently removed.
        </p>
      </DeleteConfirmModal>

      <Modal
        open={settingsModalOpen}
        onClose={() => setSettingsModalOpen(false)}
        title="Plugin Settings"
        size="md"
        footer={
          <>
            <Button variant="secondary" onClick={() => setSettingsModalOpen(false)}>Cancel</Button>
            <Button onClick={handleSaveSettings} loading={updateSettings.isPending}>Save</Button>
          </>
        }
      >
        {Object.keys(editedSettings).length > 0 ? (
          <div className={styles.settingsFields}>
            {Object.entries(editedSettings).map(([key, value]) => (
              <Input
                key={key}
                label={key}
                value={value}
                onChange={(v) =>
                  setEditedSettings((prev) => ({ ...prev, [key]: v }))
                }
              />
            ))}
          </div>
        ) : (
          <p className={styles.descriptionText}>No configurable settings</p>
        )}
      </Modal>
    </div>
  );
}
