/**
 * Tool Settings Panel
 *
 * Renders a schema-driven settings form for tools.
 * Uses the ToolSettingsSchema to dynamically generate form fields.
 */

import { useState, useEffect } from 'react';
import { Save } from 'lucide-react';
import {
  Button,
  Input,
  Select,
  Toggle,
  PanelSection,
} from '@/components/ui';
import type { ToolSettingsSchema, ToolSettingsField } from '@mukuro/client';
import styles from './ToolSettingsPanel.module.css';

interface ToolSettingsPanelProps {
  toolId: string;
  toolName: string;
  schema: ToolSettingsSchema;
}

type FieldValue = string | number | boolean;

export function ToolSettingsPanel({ toolId, toolName, schema }: ToolSettingsPanelProps) {
  const [values, setValues] = useState<Record<string, FieldValue>>({});
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);

  // Initialize with default values
  useEffect(() => {
    const defaults: Record<string, FieldValue> = {};
    for (const field of schema.fields) {
      if (field.defaultValue !== undefined) {
        defaults[field.key] = field.defaultValue as FieldValue;
      } else {
        // Set type-appropriate empty defaults
        switch (field.type) {
          case 'number':
            defaults[field.key] = 0;
            break;
          case 'toggle':
            defaults[field.key] = false;
            break;
          default:
            defaults[field.key] = '';
        }
      }
    }
    setValues(defaults);
  }, [schema]);

  const handleChange = (key: string, value: FieldValue) => {
    setValues((prev) => ({ ...prev, [key]: value }));
    setDirty(true);
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      // TODO: Call API to save tool settings
      // await saveToolSettings(toolId, values);
      console.log('Saving tool settings:', { toolId, toolName, values });
      setDirty(false);
    } finally {
      setSaving(false);
    }
  };

  return (
    <PanelSection
      title={schema.title}
      action={
        <Button
          size="sm"
          onClick={handleSave}
          loading={saving}
          disabled={!dirty}
          leftIcon={<Save style={{ width: 12, height: 12 }} />}
        >
          Save
        </Button>
      }
    >
      {schema.description && (
        <p className={styles.description}>{schema.description}</p>
      )}
      <div className={styles.fields}>
        {schema.fields.map((field) => (
          <SchemaField
            key={field.key}
            field={field}
            value={values[field.key]}
            onChange={(v) => handleChange(field.key, v)}
          />
        ))}
      </div>
    </PanelSection>
  );
}

interface SchemaFieldProps {
  field: ToolSettingsField;
  value: FieldValue | undefined;
  onChange: (value: FieldValue) => void;
}

function SchemaField({ field, value, onChange }: SchemaFieldProps) {
  const renderField = () => {
    switch (field.type) {
      case 'text':
      case 'secret':
        return (
          <Input
            label={field.label}
            type={field.type === 'secret' ? 'password' : 'text'}
            value={String(value ?? '')}
            onChange={(v) => onChange(v)}
            placeholder={field.placeholder}
          />
        );

      case 'textarea':
        return (
          <div className={styles.fieldWrapper}>
            <label className={styles.fieldLabel}>{field.label}</label>
            <textarea
              className={styles.textarea}
              value={String(value ?? '')}
              onChange={(e) => onChange(e.target.value)}
              placeholder={field.placeholder}
              rows={4}
            />
          </div>
        );

      case 'number':
        return (
          <Input
            label={field.label}
            type="number"
            value={String(value ?? '')}
            onChange={(v) => onChange(parseFloat(v) || 0)}
            placeholder={field.placeholder}
          />
        );

      case 'toggle':
        return (
          <Toggle
            checked={Boolean(value)}
            onChange={(checked) => onChange(checked)}
            label={field.label}
            description={field.description}
          />
        );

      case 'select':
        return (
          <Select
            label={field.label}
            options={field.options ?? []}
            value={String(value ?? '')}
            onChange={(v) => onChange(v)}
          />
        );

      default:
        return null;
    }
  };

  // Toggle already handles its own description
  if (field.type === 'toggle' || field.type === 'textarea') {
    return renderField();
  }

  // Wrap other fields with description
  return (
    <div className={styles.fieldWithDesc}>
      {renderField()}
      {field.description && (
        <span className={styles.fieldDesc}>{field.description}</span>
      )}
    </div>
  );
}
