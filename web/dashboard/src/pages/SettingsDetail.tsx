import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { Save } from 'lucide-react';
import {
  Button,
  Input,
  Select,
  Toggle,
  Loading,
  PanelSection,
} from '@/components/ui';
import {
  useAllSettings,
  useUpdateRetrySettings,
  useUpdateAgentSettings,
  useUpdateModelSettings,
  useUpdateThinkingSettings,
} from '@/hooks';
import type { ThinkingLevel } from '@mukuro/client';
import styles from './SettingsDetail.module.css';

const thinkingLevelOptions = [
  { value: 'off', label: 'Off' },
  { value: 'minimal', label: 'Minimal' },
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
  { value: 'xhigh', label: 'Extra High' },
];

const sectionMeta: Record<string, { title: string; desc: string }> = {
  retry: { title: 'Retry Settings', desc: 'Configure retry behavior for failed API calls' },
  agent: { title: 'Agent Settings', desc: 'Configure agent loop parameters' },
  model: { title: 'Model Settings', desc: 'Configure the AI model parameters' },
  thinking: { title: 'Thinking Settings', desc: 'Configure extended thinking behavior' },
};

export function SettingsDetail() {
  const { section } = useParams<{ section: string }>();
  const { data: settings, isLoading } = useAllSettings();

  if (isLoading) {
    return <Loading message="Loading settings..." />;
  }

  if (!section || !sectionMeta[section]) {
    return (
      <div className={styles.emptyState}>
        <p>Unknown settings section</p>
      </div>
    );
  }

  const meta = sectionMeta[section];

  return (
    <div className={styles.page}>
      <div>
        <h1 className={styles.pageTitle}>{meta.title}</h1>
        <p className={styles.pageDesc}>{meta.desc}</p>
      </div>

      {section === 'retry' && settings && <RetrySection settings={settings.retry} />}
      {section === 'agent' && settings && <AgentSection settings={settings.agent} />}
      {section === 'model' && settings && <ModelSection settings={settings.model} />}
      {section === 'thinking' && <ThinkingSection />}
    </div>
  );
}

function RetrySection({ settings }: { settings: { max_retries: number; initial_backoff_ms: number; max_backoff_ms: number; backoff_multiplier: number } }) {
  const updateRetry = useUpdateRetrySettings();
  const [maxRetries, setMaxRetries] = useState(settings.max_retries);
  const [initialBackoff, setInitialBackoff] = useState(settings.initial_backoff_ms);
  const [maxBackoff, setMaxBackoff] = useState(settings.max_backoff_ms);
  const [backoffMultiplier, setBackoffMultiplier] = useState(settings.backoff_multiplier);
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    setMaxRetries(settings.max_retries);
    setInitialBackoff(settings.initial_backoff_ms);
    setMaxBackoff(settings.max_backoff_ms);
    setBackoffMultiplier(settings.backoff_multiplier);
    setDirty(false);
  }, [settings]);

  const handleSave = () => {
    updateRetry.mutate(
      { max_retries: maxRetries, initial_backoff_ms: initialBackoff, max_backoff_ms: maxBackoff, backoff_multiplier: backoffMultiplier },
      { onSuccess: () => setDirty(false) }
    );
  };

  return (
    <PanelSection
      title="Configuration"
      action={
        <Button size="sm" onClick={handleSave} loading={updateRetry.isPending} disabled={!dirty} leftIcon={<Save style={{ width: 12, height: 12 }} />}>
          Save
        </Button>
      }
    >
      <div className={styles.fields}>
        <Input label="Max Retries" type="number" value={String(maxRetries)} onChange={(v) => { setMaxRetries(parseInt(v, 10) || 0); setDirty(true); }} />
        <Input label="Initial Backoff (ms)" type="number" value={String(initialBackoff)} onChange={(v) => { setInitialBackoff(parseInt(v, 10) || 0); setDirty(true); }} />
        <Input label="Max Backoff (ms)" type="number" value={String(maxBackoff)} onChange={(v) => { setMaxBackoff(parseInt(v, 10) || 0); setDirty(true); }} />
        <Input label="Backoff Multiplier" type="number" value={String(backoffMultiplier)} onChange={(v) => { setBackoffMultiplier(parseFloat(v) || 1); setDirty(true); }} />
      </div>
    </PanelSection>
  );
}

function AgentSection({ settings }: { settings: { max_iterations: number; timeout_ms: number } }) {
  const updateAgent = useUpdateAgentSettings();
  const [maxIterations, setMaxIterations] = useState(settings.max_iterations);
  const [timeoutMs, setTimeoutMs] = useState(settings.timeout_ms);
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    setMaxIterations(settings.max_iterations);
    setTimeoutMs(settings.timeout_ms);
    setDirty(false);
  }, [settings]);

  const handleSave = () => {
    updateAgent.mutate(
      { max_iterations: maxIterations, timeout_ms: timeoutMs },
      { onSuccess: () => setDirty(false) }
    );
  };

  return (
    <PanelSection
      title="Configuration"
      action={
        <Button size="sm" onClick={handleSave} loading={updateAgent.isPending} disabled={!dirty} leftIcon={<Save style={{ width: 12, height: 12 }} />}>
          Save
        </Button>
      }
    >
      <div className={styles.fields}>
        <Input label="Max Iterations" type="number" value={String(maxIterations)} onChange={(v) => { setMaxIterations(parseInt(v, 10) || 1); setDirty(true); }} />
        <Input label="Timeout (ms)" type="number" value={String(timeoutMs)} onChange={(v) => { setTimeoutMs(parseInt(v, 10) || 1000); setDirty(true); }} />
      </div>
    </PanelSection>
  );
}

function ModelSection({ settings }: { settings: { model_name: string; temperature: number | null; max_tokens: number | null } }) {
  const updateModel = useUpdateModelSettings();
  const [modelName, setModelName] = useState(settings.model_name);
  const [temperature, setTemperature] = useState(settings.temperature !== null ? String(settings.temperature) : '');
  const [maxTokens, setMaxTokens] = useState(settings.max_tokens !== null ? String(settings.max_tokens) : '');
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    setModelName(settings.model_name);
    setTemperature(settings.temperature !== null ? String(settings.temperature) : '');
    setMaxTokens(settings.max_tokens !== null ? String(settings.max_tokens) : '');
    setDirty(false);
  }, [settings]);

  const handleSave = () => {
    updateModel.mutate(
      { model_name: modelName, temperature: temperature ? parseFloat(temperature) : null, max_tokens: maxTokens ? parseInt(maxTokens, 10) : null },
      { onSuccess: () => setDirty(false) }
    );
  };

  return (
    <PanelSection
      title="Configuration"
      action={
        <Button size="sm" onClick={handleSave} loading={updateModel.isPending} disabled={!dirty} leftIcon={<Save style={{ width: 12, height: 12 }} />}>
          Save
        </Button>
      }
    >
      <div className={styles.fields}>
        <Input label="Model Name" value={modelName} onChange={(v) => { setModelName(v); setDirty(true); }} placeholder="e.g., claude-3-5-sonnet-20241022" />
        <Input label="Temperature" type="number" value={temperature} onChange={(v) => { setTemperature(v); setDirty(true); }} placeholder="0.0 - 1.0" />
        <Input label="Max Tokens" type="number" value={maxTokens} onChange={(v) => { setMaxTokens(v); setDirty(true); }} placeholder="e.g., 4096" />
      </div>
    </PanelSection>
  );
}

function ThinkingSection() {
  const updateThinking = useUpdateThinkingSettings();
  const [thinkingEnabled, setThinkingEnabled] = useState(false);
  const [thinkingLevel, setThinkingLevel] = useState<ThinkingLevel>('medium');
  const [budgetTokens, setBudgetTokens] = useState('');
  const [dirty, setDirty] = useState(false);

  const handleSave = () => {
    updateThinking.mutate(
      { enabled: thinkingEnabled, level: thinkingLevel, budget_tokens: budgetTokens ? parseInt(budgetTokens, 10) : null },
      { onSuccess: () => setDirty(false) }
    );
  };

  return (
    <PanelSection
      title="Configuration"
      action={
        <Button size="sm" onClick={handleSave} loading={updateThinking.isPending} disabled={!dirty} leftIcon={<Save style={{ width: 12, height: 12 }} />}>
          Save
        </Button>
      }
    >
      <div className={styles.fields}>
        <Toggle
          checked={thinkingEnabled}
          onChange={(checked) => { setThinkingEnabled(checked); setDirty(true); }}
          label="Enable Thinking"
          description="Allow the model to think before responding"
        />
        <Select
          label="Thinking Level"
          options={thinkingLevelOptions}
          value={thinkingLevel}
          onChange={(value) => { setThinkingLevel(value as ThinkingLevel); setDirty(true); }}
          disabled={!thinkingEnabled}
        />
        <Input
          label="Budget Tokens"
          type="number"
          value={budgetTokens}
          onChange={(v) => { setBudgetTokens(v); setDirty(true); }}
          placeholder="Optional token budget"
          disabled={!thinkingEnabled}
        />
      </div>
    </PanelSection>
  );
}
