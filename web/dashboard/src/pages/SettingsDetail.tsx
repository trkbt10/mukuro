import { useState, useEffect, useMemo } from 'react';
import { useParams } from 'react-router-dom';
import { Save, Eye, EyeOff } from 'lucide-react';
import {
  Button,
  Input,
  Select,
  Toggle,
  Loading,
  PanelSection,
} from '@/components/ui';
import { PageToolbar } from '@/components/layout/PageToolbar';
import {
  useAllSettings,
  useUpdateRetrySettings,
  useUpdateAgentSettings,
  useModelInferenceSettings,
  useUpdateModelInferenceSettings,
  useAiProviders,
  useUpdateAiProvider,
  useProviderModels,
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
};

export function SettingsDetail() {
  const { section, providerName } = useParams<{ section?: string; providerName?: string }>();
  const { data: settings, isLoading } = useAllSettings();

  // Provider detail page: /settings/ai-providers/:providerName
  if (providerName) {
    return <ProviderDetailPage providerName={providerName} />;
  }

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
      <PageToolbar
        back="/settings"
        title={meta.title}
      />

      {section === 'retry' && settings && <RetrySection settings={settings.retry} />}
      {section === 'agent' && settings && <AgentSection settings={settings.agent} />}
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

function ProviderDetailPage({ providerName }: { providerName: string }) {
  const { data: providers, isLoading: providerLoading } = useAiProviders();
  const { data: inferenceSettings, isLoading: inferenceLoading } = useModelInferenceSettings();

  if (providerLoading || inferenceLoading) {
    return <Loading message={`Loading ${providerName} settings...`} />;
  }

  const provider = providers?.find((p) => p.name === providerName);

  if (!provider) {
    return (
      <div className={styles.emptyState}>
        <p>Provider "{providerName}" not found</p>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      <PageToolbar
        back="/settings"
        title={providerName}
      />

      <ProviderConnectionSection providerName={providerName} provider={provider} />
      <ModelInferenceSection inferenceSettings={inferenceSettings ?? null} />
    </div>
  );
}

function ProviderConnectionSection({ providerName, provider }: {
  providerName: string;
  provider: { base_url: string | null; has_api_key: boolean; default_model: string; use_responses_api: boolean };
}) {
  const updateProvider = useUpdateAiProvider();
  const { data: knownModels } = useProviderModels(providerName);
  const [baseUrl, setBaseUrl] = useState(provider.base_url ?? '');
  const [apiKey, setApiKey] = useState('');
  const [apiKeyDirty, setApiKeyDirty] = useState(false);
  const [showApiKey, setShowApiKey] = useState(false);
  const [defaultModel, setDefaultModel] = useState(provider.default_model);
  const [useResponsesApi, setUseResponsesApi] = useState(provider.use_responses_api);
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    setBaseUrl(provider.base_url ?? '');
    setApiKey('');
    setApiKeyDirty(false);
    setShowApiKey(false);
    setDefaultModel(provider.default_model);
    setUseResponsesApi(provider.use_responses_api);
    setDirty(false);
  }, [provider]);

  const modelOptions = useMemo(() => {
    const opts = (knownModels ?? []).map((m: string) => ({ value: m, label: m }));
    if (defaultModel && !opts.some((o: { value: string }) => o.value === defaultModel)) {
      opts.unshift({ value: defaultModel, label: defaultModel });
    }
    return opts;
  }, [knownModels, defaultModel]);

  const handleSave = () => {
    const update: Record<string, unknown> = {
      base_url: baseUrl || null,
      default_model: defaultModel,
      use_responses_api: useResponsesApi,
    };
    if (apiKeyDirty && apiKey) {
      update.api_key = apiKey;
    }
    updateProvider.mutate(
      { name: providerName, update },
      { onSuccess: () => { setDirty(false); setApiKeyDirty(false); } }
    );
  };

  const apiKeyPlaceholder = provider.has_api_key ? '********' : 'Enter API key';

  return (
    <PanelSection
      title="Provider Connection"
      action={
        <Button size="sm" onClick={handleSave} loading={updateProvider.isPending} disabled={!dirty} leftIcon={<Save style={{ width: 12, height: 12 }} />}>
          Save
        </Button>
      }
    >
      <div className={styles.fields}>
        <Input
          label="Base URL"
          value={baseUrl}
          onChange={(v) => { setBaseUrl(v); setDirty(true); }}
          placeholder="e.g., https://api.groq.com/openai"
        />
        <div style={{ position: 'relative' }}>
          <Input
            label="API Key"
            type={showApiKey ? 'text' : 'password'}
            value={apiKey}
            onChange={(v) => { setApiKey(v); setApiKeyDirty(true); setDirty(true); }}
            placeholder={apiKeyPlaceholder}
          />
          <button
            type="button"
            onClick={() => setShowApiKey(!showApiKey)}
            style={{
              position: 'absolute',
              right: 8,
              top: 28,
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              padding: 4,
              color: 'var(--mk-text-muted)',
              display: 'flex',
              alignItems: 'center',
            }}
            aria-label={showApiKey ? 'Hide API key' : 'Show API key'}
          >
            {showApiKey ? <EyeOff style={{ width: 14, height: 14 }} /> : <Eye style={{ width: 14, height: 14 }} />}
          </button>
        </div>
        {modelOptions.length > 0 ? (
          <Select
            label="Default Model"
            options={modelOptions}
            value={defaultModel}
            onChange={(v) => { setDefaultModel(v); setDirty(true); }}
          />
        ) : (
          <Input
            label="Default Model"
            value={defaultModel}
            onChange={(v) => { setDefaultModel(v); setDirty(true); }}
            placeholder="e.g., gpt-4o"
          />
        )}
        <Toggle
          checked={useResponsesApi}
          onChange={(checked) => { setUseResponsesApi(checked); setDirty(true); }}
          label="Use Responses API"
          description="Use the OpenAI Responses API format instead of Chat Completions"
        />
      </div>
    </PanelSection>
  );
}

function ModelInferenceSection({ inferenceSettings }: {
  inferenceSettings: { model_name: string; temperature: number | null; max_tokens: number | null; thinking_enabled: boolean; thinking_level: ThinkingLevel; thinking_budget_tokens: number | null } | null;
}) {
  const updateModelInference = useUpdateModelInferenceSettings();
  const [temperature, setTemperature] = useState('');
  const [maxTokens, setMaxTokens] = useState('');
  const [thinkingEnabled, setThinkingEnabled] = useState(false);
  const [thinkingLevel, setThinkingLevel] = useState<ThinkingLevel>('medium');
  const [budgetTokens, setBudgetTokens] = useState('');
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    if (inferenceSettings) {
      setTemperature(inferenceSettings.temperature !== null ? String(inferenceSettings.temperature) : '');
      setMaxTokens(inferenceSettings.max_tokens !== null ? String(inferenceSettings.max_tokens) : '');
      setThinkingEnabled(inferenceSettings.thinking_enabled);
      setThinkingLevel(inferenceSettings.thinking_level);
      setBudgetTokens(inferenceSettings.thinking_budget_tokens !== null ? String(inferenceSettings.thinking_budget_tokens) : '');
      setDirty(false);
    }
  }, [inferenceSettings]);

  const handleSave = () => {
    updateModelInference.mutate(
      {
        model_name: inferenceSettings?.model_name ?? '',
        temperature: temperature ? parseFloat(temperature) : null,
        max_tokens: maxTokens ? parseInt(maxTokens, 10) : null,
        thinking_enabled: thinkingEnabled,
        thinking_level: thinkingLevel,
        thinking_budget_tokens: budgetTokens ? parseInt(budgetTokens, 10) : null,
      },
      { onSuccess: () => setDirty(false) }
    );
  };

  return (
    <>
      <PanelSection
        title="Inference Parameters"
        action={
          <Button size="sm" onClick={handleSave} loading={updateModelInference.isPending} disabled={!dirty} leftIcon={<Save style={{ width: 12, height: 12 }} />}>
            Save
          </Button>
        }
      >
        <div className={styles.fields}>
          <Input label="Temperature" type="number" value={temperature} onChange={(v) => { setTemperature(v); setDirty(true); }} placeholder="API default (leave empty)" />
          <Input label="Max Tokens" type="number" value={maxTokens} onChange={(v) => { setMaxTokens(v); setDirty(true); }} placeholder="API default (leave empty)" />
        </div>
      </PanelSection>
      <PanelSection title="Extended Thinking">
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
    </>
  );
}
