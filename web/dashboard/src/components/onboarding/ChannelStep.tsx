import { useState } from 'react';
import { Button, Input, Select, Textarea, Toggle, toast } from '@/components/ui';
import {
  useMessageProviderTypes,
  useMessageProviderSchema,
  useAddMessageProvider,
} from '@/hooks';
import type { MessageProviderAddRequest, ProviderSettingField } from '@mukuro/client';
import styles from './OnboardingWizard.module.css';

interface Props {
  onComplete: () => void;
}

export function ChannelStep({ onComplete }: Props) {
  const { data: providerTypes } = useMessageProviderTypes();
  const addProvider = useAddMessageProvider();

  const [form, setForm] = useState<MessageProviderAddRequest>({
    id: '',
    name: '',
    provider_type: '',
    enabled: true,
    auto_connect: true,
    settings: {},
  });

  const { data: schema } = useMessageProviderSchema(form.provider_type);

  const providerTypeOptions = [
    { value: '', label: 'Select a platform...' },
    ...(providerTypes?.map((t) => ({ value: t.id, label: t.name })) ?? []),
  ];

  const updateField = <K extends keyof MessageProviderAddRequest>(
    key: K,
    value: MessageProviderAddRequest[K],
  ) => {
    setForm((prev) => ({ ...prev, [key]: value }));
  };

  const updateSetting = (key: string, value: unknown) => {
    setForm((prev) => ({
      ...prev,
      settings: { ...prev.settings, [key]: value },
    }));
  };

  const handleAdd = () => {
    if (!form.id || !form.name || !form.provider_type) {
      toast.error('Type, ID and Name are required');
      return;
    }
    addProvider.mutate(form, { onSuccess: onComplete });
  };

  return (
    <div>
      <h3 className={styles.stepTitle}>Message Channel</h3>
      <p className={styles.stepDesc}>
        Connect a messaging platform (Slack, Discord, Telegram, etc.) to receive
        and respond to messages. You can add more channels later.
      </p>

      <div className={styles.channelForm}>
        <Select
          label="Platform"
          value={form.provider_type}
          onChange={(v) => updateField('provider_type', v)}
          options={providerTypeOptions}
        />

        {form.provider_type && (
          <>
            <Input
              label="Provider ID"
              placeholder="my-slack-workspace"
              value={form.id}
              onChange={(v) => updateField('id', v)}
              helperText="Unique identifier (lowercase, no spaces)"
            />
            <Input
              label="Display Name"
              placeholder="My Slack Workspace"
              value={form.name}
              onChange={(v) => updateField('name', v)}
            />

            {schema?.fields && schema.fields.length > 0 && (
              <div className={styles.settingsSection}>
                <h4 className={styles.settingsTitle}>Provider Settings</h4>
                <div className={styles.fields}>
                  {schema.fields.map((field: ProviderSettingField) => (
                    <SettingsField
                      key={field.key}
                      field={field}
                      value={form.settings?.[field.key]}
                      onChange={(value) => updateSetting(field.key, value)}
                    />
                  ))}
                </div>
              </div>
            )}

            <div className={styles.saveRow}>
              <Button
                onClick={handleAdd}
                loading={addProvider.isPending}
                disabled={!form.id || !form.name}
              >
                Add Channel & Continue
              </Button>
            </div>
          </>
        )}
      </div>
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
