import { useState } from 'react';
import { Plus, RefreshCw, Search, Plug, PlugZap, Trash2, TestTube } from 'lucide-react';
import {
  Card,
  CardContent,
  Button,
  Input,
  Badge,
  Toggle,
  Loading,
  Modal,
  Select,
  toast,
} from '@/components/ui';
import {
  useMessageProviders,
  useMessageProviderTypes,
  useMessageProviderSchema,
  useAddMessageProvider,
  useDeleteMessageProvider,
  useEnableMessageProvider,
  useDisableMessageProvider,
  useConnectMessageProvider,
  useDisconnectMessageProvider,
  useTestMessageProvider,
} from '@/hooks';
import type { MessageProviderAddRequest, ProviderSettingField } from '@mukuro/client';

export function MessageProviders() {
  const { data: providers, isLoading, refetch } = useMessageProviders();
  const { data: providerTypes } = useMessageProviderTypes();
  const addProvider = useAddMessageProvider();
  const deleteProvider = useDeleteMessageProvider();
  const enableProvider = useEnableMessageProvider();
  const disableProvider = useDisableMessageProvider();
  const connectProvider = useConnectMessageProvider();
  const disconnectProvider = useDisconnectMessageProvider();
  const testProvider = useTestMessageProvider();

  const [search, setSearch] = useState('');
  const [addModalOpen, setAddModalOpen] = useState(false);
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [newProvider, setNewProvider] = useState<MessageProviderAddRequest>({
    id: '',
    name: '',
    provider_type: 'slack',
    enabled: true,
    auto_connect: true,
    settings: {},
  });

  const { data: schema } = useMessageProviderSchema(newProvider.provider_type);

  const filteredProviders = providers?.filter(
    (p) =>
      p.name.toLowerCase().includes(search.toLowerCase()) ||
      p.id.toLowerCase().includes(search.toLowerCase())
  );

  const handleToggle = (id: string, enabled: boolean) => {
    if (enabled) {
      disableProvider.mutate(id);
    } else {
      enableProvider.mutate(id);
    }
  };

  const handleConnect = (id: string, status: string) => {
    if (status === 'connected' || status === 'connecting') {
      disconnectProvider.mutate(id);
    } else {
      connectProvider.mutate(id);
    }
  };

  const handleTest = (id: string) => {
    testProvider.mutate(id);
  };

  const handleDelete = (id: string) => {
    setDeleteId(id);
    setDeleteModalOpen(true);
  };

  const confirmDelete = () => {
    if (deleteId) {
      deleteProvider.mutate(deleteId, {
        onSuccess: () => {
          setDeleteModalOpen(false);
          setDeleteId(null);
        },
      });
    }
  };

  const handleAdd = () => {
    if (!newProvider.id || !newProvider.name) {
      toast.error('ID and Name are required');
      return;
    }
    addProvider.mutate(newProvider, {
      onSuccess: () => {
        setAddModalOpen(false);
        setNewProvider({
          id: '',
          name: '',
          provider_type: 'slack',
          enabled: true,
          auto_connect: true,
          settings: {},
        });
      },
    });
  };

  const updateSetting = (key: string, value: unknown) => {
    setNewProvider((prev) => ({
      ...prev,
      settings: { ...prev.settings, [key]: value },
    }));
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'connected':
        return <Badge variant="success">Connected</Badge>;
      case 'connecting':
        return <Badge variant="warning">Connecting</Badge>;
      case 'disconnected':
        return <Badge variant="secondary">Disconnected</Badge>;
      default:
        if (status.startsWith('error:')) {
          return <Badge variant="error">Error</Badge>;
        }
        return <Badge variant="secondary">{status}</Badge>;
    }
  };

  const getProviderTypeBadge = (type: string) => {
    const colors: Record<string, 'default' | 'secondary' | 'success' | 'warning'> = {
      slack: 'default',
      discord: 'default',
      telegram: 'default',
      webhook: 'secondary',
    };
    return <Badge variant={colors[type] ?? 'secondary'}>{type}</Badge>;
  };

  if (isLoading) {
    return <Loading message="Loading message providers..." />;
  }

  const providerTypeOptions = providerTypes?.map((type) => ({
    value: type.id,
    label: type.name,
  })) ?? [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-text">Message Providers</h1>
          <p className="text-text-secondary">
            Connect to messaging platforms like Slack, Discord, and Telegram
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => refetch()}
            leftIcon={<RefreshCw className="h-4 w-4" />}
          >
            Refresh
          </Button>
          <Button
            size="sm"
            onClick={() => setAddModalOpen(true)}
            leftIcon={<Plus className="h-4 w-4" />}
          >
            Add Provider
          </Button>
        </div>
      </div>

      <Input
        placeholder="Search providers..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        leftElement={<Search className="h-4 w-4" />}
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {filteredProviders && filteredProviders.length > 0 ? (
          filteredProviders.map((provider) => (
            <Card key={provider.id} className="flex flex-col">
              <CardContent className="flex-1">
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-text">{provider.name}</div>
                    <p className="text-sm text-text-muted truncate">{provider.id}</p>
                  </div>
                  <div className="flex items-center gap-1">
                    {getProviderTypeBadge(provider.provider_type)}
                  </div>
                </div>

                <div className="mt-4 space-y-2 text-sm text-text-secondary">
                  <div className="flex justify-between">
                    <span>Status</span>
                    {getStatusBadge(provider.status)}
                  </div>
                  <div className="flex justify-between">
                    <span>Messages Sent</span>
                    <span className="text-text">{provider.messages_sent}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Messages Received</span>
                    <span className="text-text">{provider.messages_received}</span>
                  </div>
                </div>
              </CardContent>

              <div className="border-t px-6 py-3 flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Toggle
                    checked={provider.enabled}
                    onChange={() => handleToggle(provider.id, provider.enabled)}
                    size="sm"
                  />
                  <span className="text-xs text-text-muted">
                    {provider.enabled ? 'Enabled' : 'Disabled'}
                  </span>
                </div>
                <div className="flex items-center gap-1">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleConnect(provider.id, provider.status)}
                    title={provider.status === 'connected' ? 'Disconnect' : 'Connect'}
                  >
                    {provider.status === 'connected' ? (
                      <PlugZap className="h-4 w-4 text-green-500" />
                    ) : (
                      <Plug className="h-4 w-4" />
                    )}
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleTest(provider.id)}
                    loading={testProvider.isPending}
                    title="Test Configuration"
                  >
                    <TestTube className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleDelete(provider.id)}
                    title="Delete"
                  >
                    <Trash2 className="h-4 w-4 text-red-500" />
                  </Button>
                </div>
              </div>
            </Card>
          ))
        ) : (
          <div className="col-span-full text-center py-12">
            <p className="text-text-secondary">
              {search
                ? 'No providers match your search'
                : 'No message providers configured. Add one to get started.'}
            </p>
          </div>
        )}
      </div>

      {/* Add Provider Modal */}
      <Modal
        open={addModalOpen}
        onClose={() => setAddModalOpen(false)}
        title="Add Message Provider"
        description="Connect to a messaging platform"
        size="md"
        footer={
          <>
            <Button variant="secondary" onClick={() => setAddModalOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleAdd} loading={addProvider.isPending}>
              Add Provider
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          <Select
            label="Provider Type"
            value={newProvider.provider_type}
            onChange={(e) =>
              setNewProvider((prev) => ({
                ...prev,
                provider_type: e.target.value,
                settings: {},
              }))
            }
            helperText="Select the messaging platform you want to connect to"
            options={providerTypeOptions}
          />

          <Input
            label="Provider ID"
            placeholder="my-slack-workspace"
            value={newProvider.id}
            onChange={(e) =>
              setNewProvider((prev) => ({ ...prev, id: e.target.value }))
            }
            helperText="Unique identifier for this provider (lowercase, no spaces)"
          />

          <Input
            label="Display Name"
            placeholder="My Slack Workspace"
            value={newProvider.name}
            onChange={(e) =>
              setNewProvider((prev) => ({ ...prev, name: e.target.value }))
            }
            helperText="Human-readable name for this provider"
          />

          {schema?.fields && schema.fields.length > 0 && (
            <div className="border-t pt-4 mt-4">
              <h4 className="font-medium text-text mb-3">Provider Settings</h4>
              <div className="space-y-3">
                {schema.fields.map((field: ProviderSettingField) => (
                  <SettingsField
                    key={field.key}
                    field={field}
                    value={newProvider.settings?.[field.key]}
                    onChange={(value) => updateSetting(field.key, value)}
                  />
                ))}
              </div>
            </div>
          )}
        </div>
      </Modal>

      {/* Delete Confirmation Modal */}
      <Modal
        open={deleteModalOpen}
        onClose={() => setDeleteModalOpen(false)}
        title="Delete Provider"
        description="Are you sure you want to delete this provider?"
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setDeleteModalOpen(false)}>
              Cancel
            </Button>
            <Button
              variant="danger"
              onClick={confirmDelete}
              loading={deleteProvider.isPending}
            >
              Delete
            </Button>
          </>
        }
      >
        <p className="text-text-secondary">
          This will remove the provider configuration. Any active connections will be
          terminated.
        </p>
      </Modal>
    </div>
  );
}

// Settings field component
function SettingsField({
  field,
  value,
  onChange,
}: {
  field: ProviderSettingField;
  value: unknown;
  onChange: (value: unknown) => void;
}) {
  switch (field.field_type) {
    case 'text':
    case 'url':
      return (
        <Input
          label={field.label}
          type={field.field_type === 'url' ? 'url' : 'text'}
          placeholder={field.description}
          value={(value as string) ?? ''}
          onChange={(e) => onChange(e.target.value)}
          helperText={field.description}
          required={field.required}
        />
      );
    case 'secret':
      return (
        <Input
          label={field.label}
          type="password"
          placeholder={field.description}
          value={(value as string) ?? ''}
          onChange={(e) => onChange(e.target.value)}
          helperText={field.description}
          required={field.required}
        />
      );
    case 'textarea':
      return (
        <div>
          <label className="block text-sm font-medium text-text mb-1">
            {field.label}
            {field.required && <span className="text-red-500 ml-1">*</span>}
          </label>
          <textarea
            className="w-full rounded-md border border-border bg-bg-secondary px-3 py-2 text-sm text-text placeholder:text-text-muted focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            placeholder={field.description}
            value={(value as string) ?? ''}
            onChange={(e) => onChange(e.target.value)}
            rows={3}
          />
          <p className="mt-1 text-xs text-text-muted">{field.description}</p>
        </div>
      );
    case 'number':
      return (
        <Input
          label={field.label}
          type="number"
          placeholder={field.description}
          value={(value as number)?.toString() ?? ''}
          onChange={(e) => onChange(Number(e.target.value))}
          helperText={field.description}
          required={field.required}
        />
      );
    case 'toggle':
      return (
        <div className="flex items-center justify-between">
          <div>
            <label className="block text-sm font-medium text-text">
              {field.label}
            </label>
            <p className="text-xs text-text-muted">{field.description}</p>
          </div>
          <Toggle
            checked={(value as boolean) ?? false}
            onChange={(checked) => onChange(checked)}
          />
        </div>
      );
    case 'select':
      return (
        <Select
          label={field.label}
          value={(value as string) ?? ''}
          onChange={(e) => onChange(e.target.value)}
          helperText={field.description}
          required={field.required}
          options={[
            { value: '', label: 'Select...' },
            ...(field.options?.map((opt) => ({ value: opt, label: opt })) ?? []),
          ]}
        />
      );
    default:
      return null;
  }
}
