import { useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, RefreshCw, Trash2, Settings } from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Button,
  Badge,
  Toggle,
  Loading,
  Modal,
  Input,
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
  const [editedSettings, setEditedSettings] = useState<Record<string, string>>(
    {}
  );

  if (isLoading) {
    return <Loading message="Loading plugin..." />;
  }

  if (!plugin) {
    return (
      <div className="text-center py-12">
        <p className="text-text-secondary">Plugin not found</p>
        <Link to="/plugins" className="text-primary hover:underline mt-2 block">
          Back to plugins
        </Link>
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
      onSuccess: () => {
        navigate('/plugins');
      },
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
      {
        onSuccess: () => setSettingsModalOpen(false),
      }
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

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Link
          to="/plugins"
          className="flex items-center gap-2 text-text-secondary hover:text-text transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          Back
        </Link>
      </div>

      <div className="flex items-start justify-between">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-semibold text-text">{plugin.name}</h1>
            {plugin.is_builtin && (
              <Badge variant="default" size="sm">
                Builtin
              </Badge>
            )}
          </div>
          <p className="text-text-secondary">{plugin.id}</p>
        </div>
        <div className="flex items-center gap-2">
          {!plugin.is_builtin && (
            <Button
              variant="secondary"
              size="sm"
              onClick={() => reloadPlugin.mutate(plugin.id)}
              loading={reloadPlugin.isPending}
              leftIcon={<RefreshCw className="h-4 w-4" />}
            >
              Reload
            </Button>
          )}
          <Button
            variant="secondary"
            size="sm"
            onClick={openSettingsModal}
            leftIcon={<Settings className="h-4 w-4" />}
          >
            Settings
          </Button>
          {!plugin.is_builtin && (
            <Button
              variant="danger"
              size="sm"
              onClick={() => setDeleteModalOpen(true)}
              leftIcon={<Trash2 className="h-4 w-4" />}
            >
              Delete
            </Button>
          )}
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Details</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-text-secondary">Status</span>
              <Badge variant={plugin.enabled ? 'success' : 'secondary'}>
                {plugin.enabled ? 'Active' : 'Inactive'}
              </Badge>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-text-secondary">Version</span>
              <span className="text-text">{plugin.version}</span>
            </div>
            {plugin.author && (
              <div className="flex items-center justify-between">
                <span className="text-text-secondary">Author</span>
                <span className="text-text">{plugin.author}</span>
              </div>
            )}
            {plugin.is_builtin && (
              <div className="flex items-center justify-between">
                <span className="text-text-secondary">Type</span>
                <span className="text-text">Built-in Tool</span>
              </div>
            )}
            {!plugin.is_builtin && (
              <>
                <div className="flex items-center justify-between">
                  <span className="text-text-secondary">Loaded At</span>
                  <span className="text-text">{formatDate(plugin.loaded_at)}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-text-secondary">Modified At</span>
                  <span className="text-text">{formatDate(plugin.modified_at)}</span>
                </div>
              </>
            )}
            <div className="flex items-center justify-between pt-4 border-t">
              <span className="text-text">Enable Plugin</span>
              <Toggle
                checked={plugin.enabled}
                onChange={handleToggle}
                disabled={enablePlugin.isPending || disablePlugin.isPending}
              />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Description</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-text-secondary">
              {plugin.description || 'No description available'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Permissions</CardTitle>
          </CardHeader>
          <CardContent>
            {plugin.permissions.length > 0 ? (
              <div className="flex flex-wrap gap-2">
                {plugin.permissions.map((perm) => (
                  <Badge key={perm} variant="secondary">
                    {perm}
                  </Badge>
                ))}
              </div>
            ) : (
              <p className="text-text-secondary">No special permissions</p>
            )}
          </CardContent>
        </Card>
      </div>

      <Modal
        open={deleteModalOpen}
        onClose={() => setDeleteModalOpen(false)}
        title="Delete Plugin"
        description="Are you sure you want to delete this plugin? This action cannot be undone."
        size="sm"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setDeleteModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant="danger"
              onClick={handleDelete}
              loading={deletePlugin.isPending}
            >
              Delete
            </Button>
          </>
        }
      >
        <p className="text-text-secondary">
          Plugin <strong>{plugin.name}</strong> will be permanently removed.
        </p>
      </Modal>

      <Modal
        open={settingsModalOpen}
        onClose={() => setSettingsModalOpen(false)}
        title="Plugin Settings"
        size="md"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setSettingsModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              onClick={handleSaveSettings}
              loading={updateSettings.isPending}
            >
              Save
            </Button>
          </>
        }
      >
        {Object.keys(editedSettings).length > 0 ? (
          <div className="space-y-4">
            {Object.entries(editedSettings).map(([key, value]) => (
              <Input
                key={key}
                label={key}
                value={value}
                onChange={(e) =>
                  setEditedSettings((prev) => ({
                    ...prev,
                    [key]: e.target.value,
                  }))
                }
              />
            ))}
          </div>
        ) : (
          <p className="text-text-secondary">No configurable settings</p>
        )}
      </Modal>
    </div>
  );
}
