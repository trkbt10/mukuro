import { useState } from 'react';
import { Plus, Radio, PlugZap, Activity } from 'lucide-react';
import {
  Button,
  Input,
  Textarea,
  Badge,
  Toggle,
  Loading,
  Modal,
  Select,
  toast,
  StatCard,
} from '@/components/ui';
import {
  useMessageProviders,
  useMessageProviderTypes,
  useMessageProviderSchema,
  useAddMessageProvider,
} from '@/hooks';
import type { MessageProviderAddRequest, ProviderSettingField } from '@mukuro/client';
import styles from './MessageProviders.module.css';

export function MessageProviders() {
  const { data: providers, isLoading } = useMessageProviders();
  const { data: providerTypes } = useMessageProviderTypes();
  const addProvider = useAddMessageProvider();

  const [addModalOpen, setAddModalOpen] = useState(false);
  const [newProvider, setNewProvider] = useState<MessageProviderAddRequest>({
    id: '',
    name: '',
    provider_type: 'slack',
    enabled: true,
    auto_connect: true,
    settings: {},
  });

  const { data: schema } = useMessageProviderSchema(newProvider.provider_type);

  const handleAdd = () => {
    if (!newProvider.id || !newProvider.name) {
      toast.error('ID and Name are required');
      return;
    }
    addProvider.mutate(newProvider, {
      onSuccess: () => {
        setAddModalOpen(false);
        setNewProvider({ id: '', name: '', provider_type: 'slack', enabled: true, auto_connect: true, settings: {} });
      },
    });
  };

  const updateSetting = (key: string, value: unknown) => {
    setNewProvider((prev) => ({
      ...prev,
      settings: { ...prev.settings, [key]: value },
    }));
  };

  if (isLoading) {
    return <Loading message="Loading providers..." />;
  }

  const total = providers?.length ?? 0;
  const connected = providers?.filter((p) => p.status === 'connected').length ?? 0;
  const enabled = providers?.filter((p) => p.enabled).length ?? 0;

  const providerTypeOptions = providerTypes?.map((type) => ({
    value: type.id,
    label: type.name,
  })) ?? [];

  return (
    <div className={styles.page}>
      <div className={styles.header}>
        <div>
          <h1 className={styles.pageTitle}>Message Providers</h1>
          <p className={styles.pageDesc}>Manage messaging platform connections. Select one from the sidebar to view details.</p>
        </div>
        <Button size="sm" onClick={() => setAddModalOpen(true)} leftIcon={<Plus style={{ width: 14, height: 14 }} />}>
          Add Provider
        </Button>
      </div>

      <div className={styles.statGrid}>
        <StatCard label="Total" value={total} icon={Radio} iconBg="var(--mk-accent-subtle)" iconColor="var(--mk-accent)" />
        <StatCard label="Connected" value={connected} icon={PlugZap} iconBg="var(--mk-success-subtle)" iconColor="var(--mk-success)" />
        <StatCard label="Enabled" value={enabled} icon={Activity} iconBg="var(--mk-info-subtle)" iconColor="var(--mk-info)" />
      </div>

      {total > 0 && (
        <div className={styles.providerList}>
          {providers?.map((p) => (
            <div key={p.id} className={styles.providerRow}>
              <div className={styles.providerInfo}>
                <span className={styles.providerName}>{p.name}</span>
                <Badge variant="default" size="sm">{p.provider_type}</Badge>
              </div>
              <Badge
                variant={p.status === 'connected' ? 'success' : p.status === 'connecting' ? 'warning' : 'default'}
                size="sm"
              >
                {p.status}
              </Badge>
            </div>
          ))}
        </div>
      )}

      <Modal
        open={addModalOpen}
        onClose={() => setAddModalOpen(false)}
        title="Add Message Provider"
        description="Connect to a messaging platform"
        size="md"
        footer={
          <>
            <Button variant="secondary" onClick={() => setAddModalOpen(false)}>Cancel</Button>
            <Button onClick={handleAdd} loading={addProvider.isPending}>Add Provider</Button>
          </>
        }
      >
        <div className={styles.modalFields}>
          <Select
            label="Provider Type"
            value={newProvider.provider_type}
            onChange={(value) => setNewProvider((prev) => ({ ...prev, provider_type: value, settings: {} }))}
            helperText="Select the messaging platform you want to connect to"
            options={providerTypeOptions}
          />
          <Input
            label="Provider ID"
            placeholder="my-slack-workspace"
            value={newProvider.id}
            onChange={(v) => setNewProvider((prev) => ({ ...prev, id: v }))}
            helperText="Unique identifier for this provider (lowercase, no spaces)"
          />
          <Input
            label="Display Name"
            placeholder="My Slack Workspace"
            value={newProvider.name}
            onChange={(v) => setNewProvider((prev) => ({ ...prev, name: v }))}
            helperText="Human-readable name for this provider"
          />

          {schema?.fields && schema.fields.length > 0 && (
            <div className={styles.settingsSection}>
              <h4 className={styles.settingsTitle}>Provider Settings</h4>
              <div className={styles.settingsFields}>
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
    </div>
  );
}

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
          placeholder={field.description}
          value={(value as string) ?? ''}
          onChange={(v) => onChange(v)}
          helperText={field.description}
        />
      );
    case 'secret':
      return (
        <Input
          label={field.label}
          type="password"
          placeholder={field.description}
          value={(value as string) ?? ''}
          onChange={(v) => onChange(v)}
          helperText={field.description}
        />
      );
    case 'textarea':
      return (
        <Textarea
          label={field.label}
          placeholder={field.description}
          value={(value as string) ?? ''}
          onChange={(e) => onChange(e.target.value)}
          rows={3}
          helperText={field.description}
        />
      );
    case 'number':
      return (
        <Input
          label={field.label}
          type="number"
          placeholder={field.description}
          value={(value as number)?.toString() ?? ''}
          onChange={(v) => onChange(Number(v))}
          helperText={field.description}
        />
      );
    case 'toggle':
      return (
        <div className={styles.toggleField}>
          <div>
            <label className={styles.toggleFieldLabel}>{field.label}</label>
            <p className={styles.toggleFieldDesc}>{field.description}</p>
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
          onChange={(v) => onChange(v)}
          helperText={field.description}
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
