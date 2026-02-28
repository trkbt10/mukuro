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
import type { ThinkingLevel, ProviderSettings } from '@mukuro/client';
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
  'model-inference': { title: 'Model & Inference', desc: 'Configure the AI model and extended thinking behavior' },
  'ai-providers': { title: 'AI Providers', desc: 'Configure provider API keys, base URLs, and model selection' },
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
      {section === 'model-inference' && <ModelInferenceSection />}
      {section === 'ai-providers' && <AiProvidersSection />}
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

function ModelInferenceSection() {
  const { data: settings } = useModelInferenceSettings();
  const updateModelInference = useUpdateModelInferenceSettings();
  const [modelName, setModelName] = useState('');
  const [temperature, setTemperature] = useState('');
  const [maxTokens, setMaxTokens] = useState('');
  const [thinkingEnabled, setThinkingEnabled] = useState(false);
  const [thinkingLevel, setThinkingLevel] = useState<ThinkingLevel>('medium');
  const [budgetTokens, setBudgetTokens] = useState('');
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    if (settings) {
      setModelName(settings.model_name);
      setTemperature(settings.temperature !== null ? String(settings.temperature) : '');
      setMaxTokens(settings.max_tokens !== null ? String(settings.max_tokens) : '');
      setThinkingEnabled(settings.thinking_enabled);
      setThinkingLevel(settings.thinking_level);
      setBudgetTokens(settings.thinking_budget_tokens !== null ? String(settings.thinking_budget_tokens) : '');
      setDirty(false);
    }
  }, [settings]);

  const handleSave = () => {
    updateModelInference.mutate(
      {
        model_name: modelName,
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
        title="Model"
        action={
          <Button size="sm" onClick={handleSave} loading={updateModelInference.isPending} disabled={!dirty} leftIcon={<Save style={{ width: 12, height: 12 }} />}>
            Save
          </Button>
        }
      >
        <div className={styles.fields}>
          <Input label="Model Name" value={modelName} onChange={(v) => { setModelName(v); setDirty(true); }} placeholder="e.g., claude-sonnet-4-20250514" />
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

function AiProvidersSection() {
  const { data: providers, isLoading } = useAiProviders();

  if (isLoading) {
    return <Loading message="Loading providers..." />;
  }

  if (!providers || providers.length === 0) {
    return (
      <PanelSection title="Providers">
        <p style={{ color: 'var(--mk-text-muted)', fontSize: '0.8125rem' }}>
          No providers configured. Add a provider in your config file.
        </p>
      </PanelSection>
    );
  }

  return (
    <>
      {providers.map((p) => (
        <ProviderCard key={p.name} provider={p} />
      ))}
    </>
  );
}

function ProviderCard({ provider }: { provider: ProviderSettings }) {
  const updateProvider = useUpdateAiProvider();
  const { data: knownModels } = useProviderModels(provider.name);
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
    const opts = (knownModels ?? []).map((m) => ({ value: m, label: m }));
    // Ensure current model is in the list
    if (defaultModel && !opts.some((o) => o.value === defaultModel)) {
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
      { name: provider.name, update },
      { onSuccess: () => { setDirty(false); setApiKeyDirty(false); } }
    );
  };

  const apiKeyPlaceholder = provider.has_api_key ? '********' : 'Enter API key';

  return (
    <PanelSection
      title={provider.name}
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
